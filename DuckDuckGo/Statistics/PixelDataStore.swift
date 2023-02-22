//
//  PixelDataStore.swift
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

protocol PixelDataStore {

    func value(forKey key: String) -> Double?
    func set(_ value: Double, forKey: String, completionHandler: ((Error?) -> Void)?)

    func value(forKey key: String) -> Int?
    func set(_ value: Int, forKey: String, completionHandler: ((Error?) -> Void)?)

    func value(forKey key: String) -> String?
    func set(_ value: String, forKey: String, completionHandler: ((Error?) -> Void)?)

    func removeValue(forKey key: String, completionHandler: ((Error?) -> Void)?)

}

extension PixelDataStore {
    func set(_ value: Double, forKey key: String) {
        set(value, forKey: key, completionHandler: nil)
    }

    func set(_ value: Int, forKey key: String) {
        set(value, forKey: key, completionHandler: nil)
    }

    func set(_ value: String, forKey key: String) {
        set(value, forKey: key, completionHandler: nil)
    }

    func removeValue(forKey key: String) {
        removeValue(forKey: key, completionHandler: nil)
    }
}

extension PixelData {
    fileprivate static let sharedPixelDataStore = LocalPixelDataStore<PixelData>()
}
private extension LocalPixelDataStore where T == PixelData {
    convenience init() {
        self.init(context: Database.shared.makeContext(concurrencyType: .mainQueueConcurrencyType, name: "PixelData"),
                  updateModel: PixelData.update,
                  entityName: PixelData.className())
    }
}
enum PixelDataStoreError: Error {
    case objectNotFound
}

final class LocalPixelDataStore<T: NSManagedObject>: PixelDataStore {
    static var shared: LocalPixelDataStore<PixelData> { PixelData.sharedPixelDataStore }

    private let context: NSManagedObjectContext
    private let entityName: String
    private(set) lazy var cache: [String: NSObject] = loadAll()
    private let updateModel: (T) -> (PixelDataRecord) throws -> Void

    init(context: NSManagedObjectContext, updateModel: @escaping (T) -> (PixelDataRecord) throws -> Void, entityName: String = T.className()) {
        self.updateModel = updateModel
        self.context = context
        self.entityName = entityName
    }

    private func loadAll() -> [String: NSObject] {
        let fetchRequest = PixelData.fetchRequest() as NSFetchRequest<PixelData>
        var dict = [String: NSObject]()

        context.performAndWait { [context] in
            do {
                let result = try context.fetch(fetchRequest)
                for item in result {
                    guard let record = item.valueRepresentation() else {
                        assertionFailure("LocalPixelDataStore: could not load PixelDataRecord")
                        continue
                    }

                    dict[record.key] = record.value
                }
            } catch {
            }
        }
        return dict
    }

    private func predicate(forKey key: String) -> NSPredicate {
        return NSPredicate(format: "key = %@", key)
    }

    private func update(record: PixelDataRecord, completionHandler: ((Error?) -> Void)?) {
        cache[record.key] = record.value
        let predicate = self.predicate(forKey: record.key)

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context, updateModel, entityName] in
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.predicate = predicate

                let fetchResults = try context.fetch(fetchRequest)
                let managedObject: T = try {
                    if let managedObject = fetchResults.first as? T {
                        return managedObject
                    } else if let managedObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? T {
                        return managedObject
                    }
                    assertionFailure("Could not insert new object of type \(entityName)")
                    throw PixelDataStoreError.objectNotFound
                }()

                try updateModel(managedObject)(record)
                try context.save()
                mainQueueCompletion(nil)

            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func value(forKey key: String) -> Double? {
        return (cache[key] as? NSNumber)?.doubleValue
    }

    func value(forKey key: String) -> Int? {
        return (cache[key] as? NSNumber)?.intValue
    }

    func value(forKey key: String) -> String? {
        return cache[key] as? String
    }

    func set(_ value: Double, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        update(record: PixelDataRecord(key: key, value: NSNumber(value: value)), completionHandler: completionHandler)
    }

    func set(_ value: Int, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        update(record: PixelDataRecord(key: key, value: NSNumber(value: value)), completionHandler: completionHandler)
    }

    func set(_ value: String, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        update(record: PixelDataRecord(key: key, value: value as NSString), completionHandler: completionHandler)
    }

    func removeValue(forKey key: String, completionHandler: ((Error?) -> Void)?) {
        self.cache.removeValue(forKey: key)
        let predicate = self.predicate(forKey: key)

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context, entityName] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
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

}
