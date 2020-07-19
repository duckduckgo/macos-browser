//
//  Database.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

class Database {

    static let shared = Database()

    private(set) var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Database: Unable to load persistent stores: \(error)")
            }
        }

        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    #if DEBUG
    func reset() {
        let coordinator = persistentContainer.persistentStoreCoordinator
        for store in coordinator.persistentStores where store.url != nil {
            do {
                try coordinator.remove(store)
            } catch let error {
                os_log("Database: Reset failed - %s", log: OSLog.Category.general, type: .error, error.localizedDescription)
                return
            }

            if let path = store.url?.path {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch let error {
                    os_log("Database: Reset failed - %s", log: OSLog.Category.general, type: .error, error.localizedDescription)
                    return
                }
                os_log("Database: %s removed", log: OSLog.Category.general, type: .debug, path)
            }
        }

        os_log("Database: Reset successful", log: OSLog.Category.general, type: .debug)
    }
    #endif

}
