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
    func set(_ value: Double, forKey: String)

    func value(forKey key: String) -> Int?
    func set(_ value: Int, forKey: String)

    func value(forKey key: String) -> String?
    func set(_ value: String, forKey: String)

    func removeValue(forKey key: String)
    
}

final class LocalPixelDataStore: PixelDataStore {
    static let shared = LocalPixelDataStore()

    private lazy var cache: [String: NSObject] = loadAll()

    private init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .mainQueueConcurrencyType, name: "PixelData")
    private func loadAll() -> [String: NSObject] {
        let fetchRequest = PixelData.fetchRequest() as NSFetchRequest<PixelData>
        var dict = [String: NSObject]()
        do {
            let result = try context.fetch(fetchRequest)
            for item in result {
                guard let record = item.valueRepresentation() else {
                    assertionFailure("LocalPixelDataStore: Key should not load PixelDataRecord")
                    continue
                }

                dict[record.key] = record.value
            }
        } catch {
        }
        return dict
    }

    private func predicate(forKey key: String) -> NSPredicate {
        return NSPredicate(format: "key = %@", key)
    }

    private func update(record: PixelDataRecord) {
        cache[record.key] = record.value
        let predicate = self.predicate(forKey: record.key)

        context.perform { [context] in
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PixelData.className())
                fetchRequest.predicate = predicate

                let fetchResults = try context.fetch(fetchRequest)
                let managedObject: PixelData = try {
                    if let managedObject = fetchResults.first as? PixelData {
                        return managedObject
                    } else if let managedObject = NSEntityDescription.insertNewObject(forEntityName: PixelData.className(),
                                                                                      into: context) as? PixelData {
                        return managedObject
                    }
                    struct ObjectNotFoundError: Error {}
                    throw ObjectNotFoundError()
                }()

                try managedObject.update(with: record)
                try context.save()

            } catch {
                assertionFailure("LocalPixelDataStore: Could not update record with \(error)")
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

    func set(_ value: Double, forKey key: String) {
        update(record: PixelDataRecord(key: key, value: NSNumber(value: value)))
    }

    func set(_ value: Int, forKey key: String) {
        update(record: PixelDataRecord(key: key, value: NSNumber(value: value)))
    }

    func set(_ value: String, forKey key: String) {
        update(record: PixelDataRecord(key: key, value: value as NSString))
    }

    func removeValue(forKey key: String) {
        let predicate = self.predicate(forKey: key)

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PixelData.className())
            deleteRequest.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            } catch {
                assertionFailure("LocalPixelDataStore: Could not remove record with \(error)")
            }
        }
    }

}
