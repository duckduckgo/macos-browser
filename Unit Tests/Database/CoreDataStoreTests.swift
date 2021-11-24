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
    lazy var store = FireproofDomainsStore(context: container.viewContext, tableName: "FireproofDomains")

    private func load(into result: inout [String: NSManagedObjectID],
                      idValue: FireproofDomainsStore.IDValueTuple) throws {
        result[idValue.value] = idValue.id
    }

    func testWhenFireproofingIsAddedThenItMustBeLoadedFromStore() throws {
        let storedId = try store.add("duckduckgo.com")

        let fireproofed = try store.load(into: .init(), self.load)
        XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId])
    }

    func testWhenFireproofingIsRemovedThenItShouldntBeLoadedFromStore() throws {
        let storedId1 = try store.add("duckduckgo.com")
        let storedId2 = try store.add("otherdomain.com")

        let e = expectation(description: "object removed")
        store.remove(objectWithId: storedId2) { [store] _ in
            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId1])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenFireproofingIsUpdatedThenIstLoadedWithNewValue() throws {
        let storedId1 = try store.add("duckduckgo.com")
        let storedId2 = try store.add("otherdomain.com")

        let e = expectation(description: "object removed")
        store.remove(objectWithId: storedId2) { [store] _ in
            // swiftlint:disable:next force_try
            let storedId3 = try! store.add("thirddomain.com")

            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, ["duckduckgo.com": storedId1,
                                         "thirddomain.com": storedId3])
            e.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenFireproofingsAreClearedThenOnlyExceptionsRemain() throws {
        _=try store.add("duckduckgo.com")
        _=try store.add("otherdomain.com")
        _=try store.add("wikipedia.org")
        _=try store.add("fireproofing.site")

        let e = expectation(description: "store cleared")
        store.clear { [store] error in
            XCTAssertNil(error)

            let fireproofed = try! store.load(into: .init(), self.load) // swiftlint:disable:this force_try

            XCTAssertEqual(fireproofed, [:])

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}
