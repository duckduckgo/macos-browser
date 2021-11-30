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

final class Database {
    
    fileprivate struct Constants {
        static let databaseName = "Database"
    }
    
    static let shared: Database = {
#if DEBUG
        if AppDelegate.isRunningTests {
            let keyStoreMockClass = (NSClassFromString("EncryptionKeyStoreMock") as? NSObject.Type)!
            let keyStoreMock = (keyStoreMockClass.init() as? EncryptionKeyStoring)!
            return Database(keyStore: keyStoreMock)
        }
#endif
        return Database()
    }()

    private let container: NSPersistentContainer
    private let storeLoadedCondition = RunLoop.ResumeCondition()
    
    var model: NSManagedObjectModel {
        return container.managedObjectModel
    }

    init(name: String = Constants.databaseName,
         model: NSManagedObjectModel = NSManagedObjectModel.mergedModel(from: [.main])!,
         keyStore: EncryptionKeyStoring = EncryptionKeyStore(generator: EncryptionKeyGenerator())) {
        do {
            try EncryptedValueTransformer<NSImage>.registerTransformer(keyStore: keyStore)
            try EncryptedValueTransformer<NSString>.registerTransformer(keyStore: keyStore)
            try EncryptedValueTransformer<NSURL>.registerTransformer(keyStore: keyStore)
            try EncryptedValueTransformer<NSNumber>.registerTransformer(keyStore: keyStore)
            try EncryptedValueTransformer<NSError>.registerTransformer(keyStore: keyStore)
            try EncryptedValueTransformer<NSData>.registerTransformer(keyStore: keyStore)
        } catch {
            fatalError("Failed to register encryption value transformers")
        }

        container = DDGPersistentContainer(name: name, managedObjectModel: model)
    }
    
    func loadStore(migrationHandler: @escaping (NSManagedObjectContext) -> Void = { _ in }) {
        container.loadPersistentStores { _, error in
            if let error = error {
                Pixel.fire(.debug(event: .dbInitializationError, error: error))
                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }
            
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = self.container.persistentStoreCoordinator
            context.name = "Migration"
            context.perform {
                migrationHandler(context)

                self.storeLoadedCondition.resolve()
            }
        }
    }
    
    func makeContext(concurrencyType: NSManagedObjectContextConcurrencyType, name: String? = nil) -> NSManagedObjectContext {
        RunLoop.current.run(until: storeLoadedCondition)

        let context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.persistentStoreCoordinator = container.persistentStoreCoordinator
        context.name = name
        
        return context
    }
}

extension NSManagedObjectContext {
    
    func deleteAll(entities: [NSManagedObject] = []) {
        for entity in entities {
            delete(entity)
        }
    }
    
    func deleteAll<T: NSManagedObject>(matching request: NSFetchRequest<T>) {
        if let result = try? fetch(request) {
            deleteAll(entities: result)
        }
    }
    
    func deleteAll(entityDescriptions: [NSEntityDescription] = []) {
        for entityDescription in entityDescriptions {
            let request = NSFetchRequest<NSManagedObject>()
            request.entity = entityDescription
            
            deleteAll(matching: request)
        }
    }
}

private class DDGPersistentContainer: NSPersistentContainer {

    override class func defaultDirectoryURL() -> URL {
        return URL.sandboxApplicationSupportURL
    }

}
