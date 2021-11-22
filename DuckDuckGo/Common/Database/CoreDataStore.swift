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

protocol DataStore: AnyObject {

    func load<Result, ManagedObject: NSManagedObject>(into initialResult: Result,
                                                      _ update: (inout Result, ManagedObject) throws -> Void) throws -> Result

    func add<Seq: Sequence, ManagedObject: NSManagedObject>(_ objects: Seq,
                                                            using update: (ManagedObject, Seq.Element) -> Void) throws
        -> [(element: Seq.Element, id: NSManagedObjectID)]

    func remove<ManagedObject: NSManagedObject>(objectsOfType _: ManagedObject.Type,
                                                withPredicate predicate: NSPredicate,
                                                completionHandler: ((Error?) -> Void)?)
    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?)

    func clear<ManagedObject: NSManagedObject>(objectsOfType _: ManagedObject.Type, completionHandler: ((Error?) -> Void)?)

}

extension DataStore {
    func add<T, ManagedObject: NSManagedObject>(_ object: T, using update: (ManagedObject) -> (T) -> Void) throws -> NSManagedObjectID {
        try add([object], using: { (managedObject: ManagedObject, object: T) in
            update(managedObject)(object)
        }).first?.id ?? { throw CoreDataStoreError.objectNotFound }()
    }
    func remove(objectWithId id: NSManagedObjectID) {
        remove(objectWithId: id, completionHandler: nil)
    }
    func remove<ManagedObject: NSManagedObject>(objectsOfType type: ManagedObject.Type, withPredicate predicate: NSPredicate) {
        remove(objectsOfType: type, withPredicate: predicate, completionHandler: nil)
    }
    func clear<ManagedObject: NSManagedObject>(objectsOfType type: ManagedObject.Type) {
        clear(objectsOfType: type, completionHandler: nil)
    }
}

enum CoreDataStoreError: Error {
    case objectNotFound
    case invalidManagedObject
}

final class CoreDataStore: DataStore {

    private let tableName: String
    private var _context: NSManagedObjectContext??

    private var context: NSManagedObjectContext? {
        if case .none = _context {
#if DEBUG
            if AppDelegate.isRunningTests {
                _context = .some(.none)
                return .none
            }
#endif
            _context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: tableName)
        }
        return _context!
    }

    init(context: NSManagedObjectContext? = nil, tableName: String) {
        if let context = context {
            self._context = .some(context)
        }
        self.tableName = tableName
    }

    func load<Result, ManagedObject: NSManagedObject>(into initialResult: Result,
                                                      _ update: (inout Result, ManagedObject) throws -> Void) throws -> Result {

        var result = initialResult
        var coreDataError: Error?

        guard let context = context else { return result }
        context.performAndWait {
            let fetchRequest = NSFetchRequest<ManagedObject>(entityName: ManagedObject.className())
            fetchRequest.returnsObjectsAsFaults = false

            do {
                result = try context.fetch(fetchRequest).reduce(into: result, update)
            } catch {
                coreDataError = error
            }
        }

        if let coreDataError = coreDataError {
            throw coreDataError
        }

        return result
    }

    func add<Seq: Sequence, ManagedObject: NSManagedObject>(_ objects: Seq,
                                                            using update: (ManagedObject, Seq.Element) -> Void) throws
        -> [(element: Seq.Element, id: NSManagedObjectID)] {

        guard let context = context else { return [] }

        var added = [(Seq.Element, NSManagedObject)]()
        added.reserveCapacity(objects.underestimatedCount)

        var error: Error?
        context.performAndWait { [context] in
            let entityName = ManagedObject.className()

            for object in objects {
                guard let managedObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? ManagedObject else {
                    error = CoreDataStoreError.invalidManagedObject
                    return
                }

                update(managedObject, object)
                added.append((object, managedObject))
            }

            do {
                try context.save()
            } catch let e {
                error = e
            }
        }
        if let error = error {
            throw error
        }
        return added.map { ($0, $1.objectID) }
    }

    func remove<ManagedObject: NSManagedObject>(objectsOfType _: ManagedObject.Type,
                                                withPredicate predicate: NSPredicate,
                                                completionHandler: ((Error?) -> Void)?) {
        guard let context = self.context else { return }

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ManagedObject.className())
            deleteRequest.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                mainQueueCompletion(nil)
            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            guard let managedObject = try? context.existingObject(with: id) else {
                assertionFailure("CoreDataStore: Failed to get Managed Object from the context")
                mainQueueCompletion(error: CoreDataStoreError.objectNotFound)
                return
            }

            context.delete(managedObject)

            do {
                try context.save()
                mainQueueCompletion(error: nil)
            } catch {
                assertionFailure("CoreDataStore: Saving of context failed")
                mainQueueCompletion(error: error)
            }
        }
    }

    func clear<ManagedObject: NSManagedObject>(objectsOfType _: ManagedObject.Type, completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
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
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                mainQueueCompletion(error: nil)
            } catch {
                mainQueueCompletion(error: error)
            }
        }
    }

}
