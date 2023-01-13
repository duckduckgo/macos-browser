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

import AppKit
import CoreData
import BrowserServicesKit
import Persistence

final class Database {
    
    fileprivate struct Constants {
        static let databaseName = "Database"
    }
    
    static let shared: CoreDataDatabase = {
        let (database, error) = makeDatabase()
        if database == nil {
            firePixelErrorIfNeeded(error: error)
            NSAlert.databaseFactoryFailed().runModal()
            NSApp.terminate(nil)
        }

        return database!
    }()

    static func makeDatabase() -> (CoreDataDatabase?, Error?) {
        func makeDatabase(keyStore: EncryptionKeyStoring) -> (CoreDataDatabase?, Error?) {
            do {
                try EncryptedValueTransformer<NSImage>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSString>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSURL>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSNumber>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSError>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSData>.registerTransformer(keyStore: keyStore)
            } catch {
                return (nil, error)
            }

            return (CoreDataDatabase(name: Constants.databaseName,
                                     containerLocation: URL.sandboxApplicationSupportURL,
                                     model: NSManagedObjectModel.mergedModel(from: [.main])!), nil)
        }

#if DEBUG
        assert(!AppDelegate.isRunningTests, "Use CoreData.---Container() methods for testing purposes")
#endif

        return makeDatabase(keyStore: EncryptionKeyStore(generator: EncryptionKeyGenerator()))
    }

    // MARK: - Pixel

    @UserDefaultsWrapper(key: .lastDatabaseFactoryFailurePixelDate, defaultValue: nil)
    static var lastDatabaseFactoryFailurePixelDate: Date?

    static func firePixelErrorIfNeeded(error: Error?) {
        let lastPixelSentAt = lastDatabaseFactoryFailurePixelDate ?? Date.distantPast

        // Fire the pixel once a day at max
        if lastPixelSentAt < Date.daysAgo(1) {
            lastDatabaseFactoryFailurePixelDate = Date()
            Pixel.fire(.debug(event: .dbMakeDatabaseError, error: error))
        }
    }
}

protocol Managed: NSFetchRequestResult {
    static var entityName: String { get }
}

extension Managed where Self: NSManagedObject {
    static var entityName: String { return entity().name! }
}

extension NSManagedObjectContext {
    func insertObject<A: NSManagedObject>() -> A where A: Managed {
        guard let obj = NSEntityDescription.insertNewObject(forEntityName: A.entityName, into: self) as? A else {
            fatalError("Wrong object type")
        }
        return obj
    }
}
