//
//  CoreDataStoreTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class CoreDataStoreTests: XCTestCase {

    let container = CoreData.fireproofingContainer()
    lazy var store = CoreDataStore(context: container.viewContext, tableName: "FireproofDomains")

    private func load(into result: inout [String: NSManagedObjectID], object: FireproofDomainManagedObject) throws {
        guard let domain = object.domainEncrypted as? String else { return }
        result[domain] = object.objectID
    }

    func testWhenFireproofingIsAddedThenItMustBeLoadedFromStore() throws {
        let storedId = try store.add("duckduckgo.com", using: FireproofDomainManagedObject.update)

        let fireproofed = try store.load(into: .init(), self.load)
        XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId])
    }

    func testWhenFireproofingIsRemovedThenItShouldntBeLoadedFromStore() throws {
        let storedId1 = try store.add("duckduckgo.com", using: FireproofDomainManagedObject.update)
        let storedId2 = try store.add("otherdomain.com", using: FireproofDomainManagedObject.update)

        let e = expectation(description: "object removed")
        store.remove(objectWithId: storedId2) { [store] _ in
            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId1])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenFireproofingIsUpdatedThenIstLoadedWithNewValue() throws {
        let storedId1 = try store.add("duckduckgo.com", using: FireproofDomainManagedObject.update)
        let storedId2 = try store.add("otherdomain.com", using: FireproofDomainManagedObject.update)

        let e = expectation(description: "object removed")
        store.remove(objectWithId: storedId2) { [store] _ in
            // swiftlint:disable:next force_try
            let storedId3 = try! store.add("thirddomain.com", using: FireproofDomainManagedObject.update)

            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId1,
                                         "thirddomain.com": storedId3])
            e.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenFireproofingsAreClearedThenOnlyExceptionsRemain() throws {
        _=try store.add("duckduckgo.com", using: FireproofDomainManagedObject.update)
        _=try store.add("otherdomain.com", using: FireproofDomainManagedObject.update)
        _=try store.add("wikipedia.org", using: FireproofDomainManagedObject.update)
        _=try store.add("fireproofing.site", using: FireproofDomainManagedObject.update)

        let e = expectation(description: "store cleared")
        store.clear(objectsOfType: FireproofDomainManagedObject.self) { [store] error in
            XCTAssertNil(error)

            let fireproofed = try! store.load(into: .init(), self.load) // swiftlint:disable:this force_try

            XCTAssertEqual(fireproofed, [:])

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}
