//
//  CoreDataStore.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreData

protocol ValueRepresentableManagedObject: NSManagedObject {
    associatedtype ValueType

    func valueRepresentation() -> ValueType?
    func update(with value: ValueType) throws
}

enum CoreDataStoreError: Error, Equatable {
    case objectNotFound
    case multipleObjectsFound
    case invalidManagedObject
}

extension CoreDataStore {

    func add(_ value: Value) throws -> NSManagedObjectID {
        try add([value]).first?.id ?? { throw CoreDataStoreError.objectNotFound }()
    }

    func remove(objectWithId id: NSManagedObjectID) {
        remove(objectWithId: id, completionHandler: nil)
    }

    func remove(objectsWithPredicate predicate: NSPredicate) {
        remove(objectsWithPredicate: predicate, completionHandler: nil)
    }

    func clear() {
        clear(completionHandler: nil)
    }

}

internal class CoreDataStore<ManagedObject: ValueRepresentableManagedObject> {

    private let tableName: String
    private var _readContext: NSManagedObjectContext??

    private var readContext: NSManagedObjectContext? {
        if case .none = _readContext {
#if DEBUG
            guard NSApp.runType.requiresEnvironment else {
                _readContext = .some(.none)
                return .none
            }
#endif
            _readContext = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: tableName)
        }
        return _readContext!
    }

    private func writeContext() -> NSManagedObjectContext? {
        guard let context = readContext else { return nil }

        let newContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        newContext.name = context.name

        return newContext
    }

    init(context: NSManagedObjectContext? = nil, tableName: String) {
        if let context = context {
            self._readContext = .some(context)
        }
        self.tableName = tableName
    }

    typealias Value = ManagedObject.ValueType
    typealias IDValueTuple = (id: NSManagedObjectID, value: Value)

    func load<Result>(objectsWithPredicate predicate: NSPredicate? = nil,
                      sortDescriptors: [NSSortDescriptor]? = nil,
                      into initialResult: Result,
                      _ accumulate: (inout Result, IDValueTuple) throws -> Void) throws -> Result {

        var result = initialResult
        var coreDataError: Error?

        guard let context = readContext else { return result }
        context.performAndWait {
            let fetchRequest = NSFetchRequest<ManagedObject>(entityName: ManagedObject.className())
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = sortDescriptors
            fetchRequest.returnsObjectsAsFaults = false

            do {
                result = try context.fetch(fetchRequest).reduce(into: result) { result, managedObject in
                    guard let value = managedObject.valueRepresentation() else { return }
                    try accumulate(&result, (managedObject.objectID, value))
                }
            } catch {
                coreDataError = error
            }
        }

        if let coreDataError = coreDataError {
            throw coreDataError
        }

        return result
    }

    func add<S: Sequence>(_ values: S) throws -> [(value: Value, id: NSManagedObjectID)] where S.Element == Value {
        guard let context = writeContext() else { return [] }

        var result: Result<[(Value, NSManagedObjectID)], Error> = .success([])

        context.performAndWait { [context] in
            let entityName = ManagedObject.className()
            var added = [(Value, NSManagedObject)]()
            added.reserveCapacity(values.underestimatedCount)

            do {
                for value in values {
                    guard let managedObject = NSEntityDescription
                            .insertNewObject(forEntityName: entityName, into: context) as? ManagedObject
                    else {
                        result = .failure(CoreDataStoreError.invalidManagedObject)
                        return
                    }

                    try managedObject.update(with: value)
                    added.append((value, managedObject))
                }

                try context.save()
                result = .success(added.map { ($0, $1.objectID) })
            } catch {
                result = .failure(error)
            }
        }
        return try result.get()
    }

    func update(objectWithPredicate predicate: NSPredicate, with value: Value, completionHandler: ((Error?) -> Void)?) {
        guard let context = writeContext() else { return }

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ManagedObject.className())
                fetchRequest.predicate = predicate

                let fetchResults = try context.fetch(fetchRequest)
                guard fetchResults.count <= 1 else { throw CoreDataStoreError.multipleObjectsFound }
                guard let managedObject = fetchResults.first as? ManagedObject else {
                    throw CoreDataStoreError.objectNotFound
                }

                try managedObject.update(with: value)
                try context.save()

                mainQueueCompletion(nil)
            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func update(objectWithId id: NSManagedObjectID, with value: Value, completionHandler: ((Error?) -> Void)?) {
        guard let context = writeContext() else { return }

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            do {
                guard let managedObject = try? context.existingObject(with: id) as? ManagedObject else {
                    assertionFailure("CoreDataStore: Failed to get Managed Object from the context")
                    throw CoreDataStoreError.objectNotFound
                }

                try managedObject.update(with: value)
                try context.save()

                mainQueueCompletion(nil)
            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func remove<T>(objectsWithPredicate predicate: NSPredicate,
                   identifiedBy identifierKeyPath: KeyPath<ManagedObject, T>,
                   completionHandler: ((Result<[T], Error>) -> Void)?) {
        guard let context = self.writeContext() else { return }

        func mainQueueCompletion(_ result: Result<[T], Error>) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(result)
            }
        }

        context.perform { [context] in
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ManagedObject.className())
                fetchRequest.predicate = predicate

                let fetchResults = try context.fetch(fetchRequest)
                var removedIds = [T]()
                removedIds.reserveCapacity(fetchResults.count)
                for result in fetchResults {
                    guard let managedObject = result as? ManagedObject else { continue }
                    removedIds.append(managedObject[keyPath: identifierKeyPath])
                    context.delete(managedObject)
                }

                try context.save()
                mainQueueCompletion(.success(removedIds))
            } catch {
                mainQueueCompletion(.failure(error))
            }
        }
    }

    func remove(objectsWithPredicate predicate: NSPredicate,
                completionHandler: ((Result<[NSManagedObjectID], Error>) -> Void)?) {
        remove(objectsWithPredicate: predicate, identifiedBy: \ManagedObject.objectID, completionHandler: completionHandler)
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        guard let context = writeContext() else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            do {
                guard let managedObject = try? context.existingObject(with: id) else {
                    assertionFailure("CoreDataStore: Failed to get Managed Object from the context")
                    throw CoreDataStoreError.objectNotFound
                }

                context.delete(managedObject)

                try context.save()
                mainQueueCompletion(error: nil)
            } catch {
                assertionFailure("CoreDataStore: Saving of context failed")
                mainQueueCompletion(error: error)
            }
        }
    }

    func clear(completionHandler: ((Error?) -> Void)?) {
        guard let context = writeContext() else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ManagedObject.className())
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)

            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                _=try context.execute(batchDeleteRequest)
                mainQueueCompletion(error: nil)
            } catch {
                mainQueueCompletion(error: error)
            }
        }
    }

}
