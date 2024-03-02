//
//  CoreDataEncryptionTests.swift
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

import XCTest
import CryptoKit
@testable import DuckDuckGo_Privacy_Browser

final class CoreDataEncryptionTests: XCTestCase {

    private lazy var mockValueTransformer: MockValueTransformer = {
        let name = NSValueTransformerName("MockValueTransformer")
        let transformer = MockValueTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)

        return transformer
    }()

    static var container = CoreData.encryptionContainer()
    static var context = container.viewContext
    var context: NSManagedObjectContext { Self.context }

    override func setUp() {
        super.setUp()

        mockValueTransformer.numberOfTransformations = 0
    }

    func testSavingEncryptedValues() {
        context.performAndWait {
            let entity = PartiallyEncryptedEntity(context: context)
            entity.date = Date()
            entity.encryptedString = "Hello, World" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }
    }

    func testFetchingEncryptedValues() {
        let timestamp = Date()

        context.performAndWait {
            let entity = PartiallyEncryptedEntity(context: context)
            entity.date = timestamp
            entity.encryptedString = "Hello, World" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }

        let result = firstPartiallyEncryptedEntity(context: context)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.date, timestamp)
        XCTAssertEqual(result?.encryptedString, "Hello, World" as NSString)
    }

    func testValueTransformers() {
        let transformer = self.mockValueTransformer

        context.performAndWait {
            let entity = MockEntity(context: context)
            entity.mockString = "Test String" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }

        XCTAssertEqual(transformer.numberOfTransformations, 1)

        let request = NSFetchRequest<NSManagedObject>(entityName: "MockEntity")

        do {
            let results = try context.fetch(request)
            let result = results[0] as? MockEntity
            XCTAssertEqual(result?.mockString, "Transformed: Test String" as NSString)
        } catch let error as NSError {
            XCTFail("Could not fetch encrypted entity: \(error), \(error.userInfo)")
        }
    }

    private func firstPartiallyEncryptedEntity(context: NSManagedObjectContext) -> PartiallyEncryptedEntity? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PartiallyEncryptedEntity")

        do {
            let results = try context.fetch(request)
            return results[0] as? PartiallyEncryptedEntity
        } catch let error as NSError {
            XCTFail("Could not fetch encrypted entity: \(error), \(error.userInfo)")
        }

        return nil
    }

}
