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
import BrowserServicesKit

final class Database {
    
    fileprivate struct Constants {
        static let databaseName = "Database"
    }
    
    static let shared: CoreDataDatabase = {
#if DEBUG
        if AppDelegate.isRunningTests {
            let keyStoreMockClass = (NSClassFromString("EncryptionKeyStoreMock") as? NSObject.Type)!
            let keyStoreMock = (keyStoreMockClass.init() as? EncryptionKeyStoring)!
            return makeDatabase(keyStore: keyStoreMock)
        }
#endif
        return makeDatabase(keyStore: EncryptionKeyStore(generator: EncryptionKeyGenerator()))
    }()

    static func makeDatabase(keyStore: EncryptionKeyStoring) -> CoreDataDatabase {
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

        return CoreDataDatabase(name: Constants.databaseName,
                                containerLocation: URL.sandboxApplicationSupportURL,
                                model: NSManagedObjectModel.mergedModel(from: [.main])!)
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
