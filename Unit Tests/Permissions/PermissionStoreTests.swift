//
//  PermissionStoreTests.swift
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

final class PermissionStoreTests: XCTestCase {

    let container = CoreData.permissionContainer()
    lazy var store = LocalPermissionStore(context: container.viewContext)

    func testWhenPermissionIsAddedThenItMustBeLoadedFromStore() throws {
        let stored = try store.add(domain: "duckduckgo.com", permissionType: .camera, allow: true)
        XCTAssertTrue(stored.allow)

        let permissions = try store.loadPermissions()
        XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored.id, allow: true),
                                           domain: "duckduckgo.com",
                                           type: .camera)])
    }

    func testWhenPermissionIsRemovedThenItShouldntBeLoadedFromStore() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .microphone, allow: true)
        let stored2 = try store.add(domain: "otherdomain.com", permissionType: .geolocation, allow: false)

        let e = expectation(description: "object removed")
        store.remove(objectWithId: stored2.id) { [store] _ in
            let permissions = try? store.loadPermissions()
            XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, allow: true),
                                               domain: "duckduckgo.com",
                                               type: .microphone)])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenPermissionIsUpdatedThenIstLoadedWithNewValue() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .microphone, allow: true)
        let stored2 = try store.add(domain: "otherdomain.com", permissionType: .geolocation, allow: true)

        let e = expectation(description: "object removed")
        store.update(objectWithId: stored2.id, allow: false) { [store] _ in
            let permissions = try? store.loadPermissions()
            XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, allow: true),
                                               domain: "duckduckgo.com",
                                               type: .microphone),
                                         .init(permission: StoredPermission(id: stored2.id, allow: false),
                                                                            domain: "otherdomain.com",
                                                                            type: .geolocation)])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}
