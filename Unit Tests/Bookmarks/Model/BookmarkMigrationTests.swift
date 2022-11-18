//
//  BookmarkMigrationTests.swift
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

import XCTest
import CoreData
@testable import DuckDuckGo_Privacy_Browser

class BookmarkMigrationTests: XCTestCase {

    private let storeType = NSSQLiteStoreType
    private let modelName = "Bookmark"

    func testMigratingStores() {
        migrateStore(from: "Bookmark", to: "Bookmark 2")
        migrateStore(from: "Bookmark 2", to: "Bookmark 3")
    }

    private func storeURL(_ version: String) -> URL? {
        let storeURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(version).sqlite" )
        return storeURL
    }

    private func createObjectModel(withVersion modelVersionName: String) -> NSManagedObjectModel? {
        let bundle = Bundle.main
        let managedObjectModelURL = bundle.url(forResource: modelName, withExtension: "momd")
        let managedObjectModelURLBundle = Bundle(url: managedObjectModelURL!)
        let managedObjectModelVersionURL = managedObjectModelURLBundle!.url(forResource: modelVersionName, withExtension: "mom")

        return NSManagedObjectModel(contentsOf: managedObjectModelVersionURL!)
    }

    private func createStore(modelVersion: String) -> NSPersistentStoreCoordinator {
        let model = createObjectModel(withVersion: modelVersion)
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)

        _ = try? storeCoordinator.addPersistentStore(ofType: storeType,
                                                 configurationName: nil,
                                                 at: storeURL(modelVersion),
                                                 options: nil)

        return storeCoordinator
    }

    private func migrateStore(from initialVersion: String, to newVersion: String) {
        let store = createStore(modelVersion: initialVersion)
        let nextVersionObjectModel = createObjectModel(withVersion: newVersion)!

        let mappingModel = NSMappingModel(from: [Bundle.main, Bundle(for: AppDelegate.self)],
                                          forSourceModel: store.managedObjectModel,
                                          destinationModel: nextVersionObjectModel)!
        let migrationManager = NSMigrationManager(sourceModel: store.managedObjectModel, destinationModel: nextVersionObjectModel)

        do {
            try migrationManager.migrateStore(from: store.persistentStores.first!.url!,
                                              sourceType: storeType,
                                              options: nil,
                                              with: mappingModel,
                                              toDestinationURL: storeURL(newVersion)!,
                                              destinationType: NSSQLiteStoreType,
                                              destinationOptions: nil)
        } catch {
            XCTAssertNil(error)
        }

        try? FileManager.default.removeItem(at: storeURL(initialVersion)!)
        try? FileManager.default.removeItem(at: storeURL(newVersion)!)
    }

}
