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

}

final class LocalPixelDataStore: PixelDataStore {
    static let shared = LocalPixelDataStore()

    private lazy var cache: [String: NSNumber] = loadAll()

    private init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .mainQueueConcurrencyType, name: "PixelData")

    private func loadAll() -> [String: NSNumber] {
        let fetchRequest = PixelData.fetchRequest() as NSFetchRequest<PixelData>
        var dict = [String: NSNumber]()
        do {
            let result = try context.fetch(fetchRequest)
            for item in result {
                guard let key = item.key else {
                    assertionFailure("LocalPixelDataStore: Key should not be nil")
                    continue
                }
                guard let value = item.valueEncrypted as? NSNumber else {
//                    assertionFailure("LocalPixelDataStore: Could not decrypt value")
                    continue
                }
                dict[key] = value
            }
        } catch {
            assertionFailure("LocalPixelDataStore: loadAll failed \(error)")
        }
        return dict
    }

    func value(forKey key: String) -> Int? {
        return cache[key]?.intValue
    }

    func value(forKey key: String) -> Double? {
        return cache[key]?.doubleValue
    }

    private func set(_ value: NSNumber, forKey key: String) {
        cache[key] = value

        context.perform { [context] in
            do {
                let fetchRequest = PixelData.fetchRequest() as NSFetchRequest<PixelData>
                fetchRequest.predicate = NSPredicate(format: "key = %@", key)
                if let pixelData = try context.fetch(fetchRequest).first {
                    pixelData.valueEncrypted = value
                } else {
                    let mobj = NSEntityDescription.insertNewObject(forEntityName: PixelData.className(),
                                                                   into: self.context)
                    guard let pixelData = mobj as? PixelData else {
                        assertionFailure("LocalPixelDataStore: Failed to init PixelData")
                        return
                    }

                    pixelData.key = key
                    pixelData.valueEncrypted = value
                }

                try self.context.save()
            } catch {
                assertionFailure("LocalPixelDataStore: Saving of context failed")
            }
        }
    }

    func set(_ value: Int, forKey key: String) {
        self.set(NSNumber(value: value), forKey: key)
    }

    func set(_ value: Double, forKey key: String) {
        self.set(NSNumber(value: value), forKey: key)
    }

}
