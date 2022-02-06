//
//  NSPersistentContainerExtension.swift
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

extension NSPersistentContainer {

    static func createPersistentContainer(at url: URL, modelName: String, bundle: Bundle) -> NSPersistentContainer {

        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let objectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing object model from: \(modelURL)")
        }

        let container = NSPersistentContainer(name: modelName, managedObjectModel: objectModel)

        let description = NSPersistentStoreDescription()
        description.url = url
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores(completionHandler: { _, error in
          if let error = error as NSError? {
            fatalError("Failed to load stores: \(error), \(error.userInfo)")
          }
        })

        return container
    }

    static func createInMemoryPersistentContainer(modelName: String, bundle: Bundle) -> NSPersistentContainer {
        // Creates a persistent store using the in-memory model, no state will be written to disk.
        // This was the approach I had seen recommended in a WWDC session, but there is also a
        // `NSInMemoryStoreType` option for doing this.
        //
        // This approach is apparently the recommended choice: https://www.donnywals.com/setting-up-a-core-data-store-for-unit-tests/
        return createPersistentContainer(at: URL(fileURLWithPath: "/dev/null"), modelName: modelName, bundle: bundle)
    }

}
