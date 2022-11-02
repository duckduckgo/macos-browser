//
//  CoreDataTestUtilities.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class CoreData {

    static func bookmarkContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "Bookmark", bundle: Bundle(for: AppDelegate.self))
    }

    static func permissionContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "Permissions", bundle: Bundle(for: AppDelegate.self))
    }

    static func fireproofingContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "FireproofDomains", bundle: Bundle(for: AppDelegate.self))
    }

    static func coreDataStoreTestsContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "TestDataModel", bundle: Bundle(for: Self.self))
    }

    static func downloadsContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "Downloads", bundle: Bundle(for: AppDelegate.self))
    }

    static func encryptionContainer() -> NSPersistentContainer {
        return createInMemoryPersistentContainer(modelName: "CoreDataEncryptionTesting", bundle: Bundle(for: CoreData.self))
    }

    static func registerValueTransformer(for propertyClass: AnyClass, with keyStore: EncryptionKeyStoring) -> NSValueTransformerName {
        guard let encodableType = propertyClass as? (NSObject & NSSecureCoding).Type else {
            fatalError("Unsupported type")
        }
        func registerValueTransformer<T: NSObject & NSSecureCoding>(_ type: T.Type) -> NSValueTransformerName {
            (try? EncryptedValueTransformer<T>.registerTransformer(keyStore: keyStore))!
            return EncryptedValueTransformer<T>.transformerName
        }
        return _openExistential(encodableType, do: registerValueTransformer)
    }

    static func registerValueTransformers(for managedObjectModel: NSManagedObjectModel) -> [NSValueTransformerName] {
        let storedClasses = managedObjectModel.entities.reduce(into: Set<String>()) { result, entity in
            result.formUnion(entity.properties.compactMap { property in
                (property as? NSAttributeDescription)?.attributeValueClassName
            })
        }.compactMap(NSClassFromString)

        let keyStore = EncryptionKeyStoreMock()
        return storedClasses.map { propertyClass in
            registerValueTransformer(for: propertyClass, with: keyStore)
        }
    }

    static func createPersistentContainer(at url: URL, modelName: String, bundle: Bundle) -> NSPersistentContainer {
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let objectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing object model from: \(modelURL)")
        }

        let transformers = registerValueTransformers(for: objectModel)
        let container = TestPersistentContainer(name: modelName,
                                                managedObjectModel: objectModel,
                                                registeredTransformers: transformers)

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

final class TestPersistentContainer: NSPersistentContainer {
    let registeredTransformers: [NSValueTransformerName]
    init(name: String, managedObjectModel model: NSManagedObjectModel, registeredTransformers: [NSValueTransformerName]) {
        self.registeredTransformers = registeredTransformers
        super.init(name: name, managedObjectModel: model)
    }

    deinit {
        for name in registeredTransformers {
            ValueTransformer.setValueTransformer(nil, forName: name)
        }
    }
}
