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

    let container = CoreData.coreDataStoreTestsContainer()
    typealias Store = CoreDataStore<TestManagedObject>
    lazy var store = Store(context: container.newBackgroundContext(), tableName: "TestDataModel")

    private func load(into result: inout [CoreDataTestStruct: NSManagedObjectID],
                      idValue: Store.IDValueTuple) throws {
        result[idValue.value] = idValue.id
    }

    func testWhenObjectIsAddedThenItMustBeLoadedFromStore() throws {
        let storedId = try store.add(.init(domain: "duckduckgo.com"))

        let fireproofed = try store.load(into: .init(), self.load)
        XCTAssertEqual(fireproofed, [.init(domain: "duckduckgo.com"): storedId])
    }

    func testWhenObjectIsRemovedThenItShouldntBeLoadedFromStore() throws {
        let storedId1 = try store.add(.init(domain: "duckduckgo.com"))
        let storedId2 = try store.add(.init(domain: "otherdomain.com"))

        let e = expectation(description: "object removed")
        store.remove(objectWithId: storedId2) { [store] error in
            XCTAssertNil(error)
            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, [.init(domain: "duckduckgo.com"): storedId1])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenObjectIsRemovedWithPredicateThenItShouldntBeLoadedFromStore() throws {
        let storedId1 = try store.add(.init(domain: "duckduckgo.com", testAttribute: "a"))
        let storedId2 = try store.add(.init(domain: "otherdomain.com", testAttribute: "b"))

        let e = expectation(description: "object removed")
        store.remove(objectsWithPredicate: NSPredicate(format: #keyPath(TestManagedObject.testAttribute) + " == %@", "b")) { [store] result in
            switch result {
            case .success(let ids):
                XCTAssertEqual(ids, [storedId2])
            case .failure(let error):
                XCTFail("unexpected error \(error)")
            }

            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, [.init(domain: "duckduckgo.com", testAttribute: "a"): storedId1])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenObjectIsUpdatedThenIstLoadedWithNewValue() throws {
        let storedId1 = try store.add(.init(domain: "duckduckgo.com"))
        let storedId2 = try store.add(.init(domain: "otherdomain.com"))

        let e = expectation(description: "object removed")
        store.update(objectWithId: storedId1, with: .init(domain: "www.duckduckgo.com", testAttribute: "a")) { [store] error in
            XCTAssertNil(error)

            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, [.init(domain: "www.duckduckgo.com", testAttribute: "a"): storedId1,
                                         .init(domain: "otherdomain.com"): storedId2])
            e.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenObjectIsUpdatedWithPredicateThenIstLoadedWithNewValue() throws {
        let storedId1 = try store.add(.init(domain: "duckduckgo.com", testAttribute: "a"))
        let storedId2 = try store.add(.init(domain: "otherdomain.com", testAttribute: "b"))

        let e = expectation(description: "object removed")
        store.update(objectWithPredicate: NSPredicate(format: #keyPath(TestManagedObject.testAttribute) + " == %@", "a"),
                     with: .init(domain: "www.duckduckgo.com", testAttribute: "a")) { [store] error in
            XCTAssertNil(error)

            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, [.init(domain: "www.duckduckgo.com", testAttribute: "a"): storedId1,
                                         .init(domain: "otherdomain.com", testAttribute: "b"): storedId2])
            e.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenUpdateWithPredicateFailsThenErrorIsReturned() throws {
        let storedId1 = try store.add(.init(domain: "duckduckgo.com", testAttribute: "a"))
        let storedId2 = try store.add(.init(domain: "otherdomain.com", testAttribute: "b"))

        let e = expectation(description: "object removed")
        store.update(objectWithPredicate: NSPredicate(format: #keyPath(TestManagedObject.testAttribute) + " == %@", "c"),
                     with: .init(domain: "www.duckduckgo.com", testAttribute: "c")) { [store] error in
            XCTAssertEqual(error as? CoreDataStoreError, CoreDataStoreError.objectNotFound)
            let fireproofed = try? store.load(into: .init(), self.load)
            XCTAssertEqual(fireproofed, [.init(domain: "duckduckgo.com", testAttribute: "a"): storedId1,
                                         .init(domain: "otherdomain.com", testAttribute: "b"): storedId2])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenObjectsAreClearedThenOnlyExceptionsRemain() throws {
        _=try store.add(.init(domain: "duckduckgo.com"))
        _=try store.add(.init(domain: "otherdomain.com"))
        _=try store.add(.init(domain: "wikipedia.org"))
        _=try store.add(.init(domain: "fireproofing.site"))

        let e = expectation(description: "store cleared")
        store.clear { [store] error in
            XCTAssertNil(error)

            let fireproofed = try! store.load(into: .init(), self.load)

            XCTAssertEqual(fireproofed, [:])

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}

public struct CoreDataTestStruct: Hashable {
    var domain: String
    var testAttribute: String?
}
extension TestManagedObject: ValueRepresentableManagedObject {

    public func update(with val: CoreDataTestStruct) {
        self.domainEncrypted = val.domain as NSString
        self.testAttribute = val.testAttribute
    }

    public func valueRepresentation() -> CoreDataTestStruct? {
        guard let domain = self.domainEncrypted as? String else { return nil }
        return CoreDataTestStruct(domain: domain, testAttribute: self.testAttribute)
    }

}
