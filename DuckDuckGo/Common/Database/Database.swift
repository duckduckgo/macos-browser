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
    
    static let shared = Database()

    private let semaphore = DispatchSemaphore(value: 0)
    private let container: NSPersistentContainer
    
    var model: NSManagedObjectModel {
        return container.managedObjectModel
    }
    
    convenience init() {
        let mainBundle = Bundle.main

        guard let managedObjectModel = NSManagedObjectModel.mergedModel(from: [mainBundle]) else { fatalError("No DB scheme found") }
        
        self.init(name: Constants.databaseName, model: managedObjectModel)
    }
    
    init(name: String, model: NSManagedObjectModel) {
        do {
            try EncryptedValueTransformer<NSImage>.registerTransformer()
            try EncryptedValueTransformer<NSString>.registerTransformer()
            try EncryptedValueTransformer<NSURL>.registerTransformer()
            try EncryptedValueTransformer<NSNumber>.registerTransformer()
        } catch {
//            fatalError("Failed to register encryption value transformers")
        }

        container = DDGPersistentContainer(name: name, managedObjectModel: model)
    }
    
    func loadStore(migrationHandler: @escaping (NSManagedObjectContext) -> Void = { _ in }) {
        container.loadPersistentStores { _, error in
            if let error = error {
                Pixel.fire(.debug(event: .dbInitializationError, error: error, countedBy: .counter))
                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }
            
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = self.container.persistentStoreCoordinator
            context.name = "Migration"
            context.perform {
                migrationHandler(context)
                self.semaphore.signal()
            }
        }
    }
    
    func makeContext(concurrencyType: NSManagedObjectContextConcurrencyType, name: String? = nil) -> NSManagedObjectContext {
        semaphore.wait()
        let context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.persistentStoreCoordinator = container.persistentStoreCoordinator
        context.name = name
        semaphore.signal()
        
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
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    } 
}
