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
@testable import PixelKit

final class PermissionStoreTests: XCTestCase {

    let container = CoreData.permissionContainer()
    lazy var store = LocalPermissionStore(context: container.viewContext)
    let pixelKit = PixelKit(dryRun: true,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: UserDefaults(),
                            fireRequest: { _, _, _, _, _, _ in })

    override func setUp() {
        PixelKit.setSharedForTesting(pixelKit: pixelKit)
    }

    func testWhenPermissionIsAddedThenItMustBeLoadedFromStore() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .camera, decision: .allow)
        XCTAssertEqual(stored1.decision, .allow)
        let stored2 = try store.add(domain: "domainname.org", permissionType: .popups, decision: .deny)
        XCTAssertEqual(stored2.decision, .deny)
        let stored3 = try store.add(domain: "domainname2.org", permissionType: .externalScheme(scheme: "asdf"), decision: .allow)
        XCTAssertEqual(stored3.decision, .allow)
        let stored4 = try store.add(domain: "domainname2.org", permissionType: .externalScheme(scheme: "dsfg"), decision: .deny)
        XCTAssertEqual(stored4.decision, .deny)

        let permissions = try store.loadPermissions()
        XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, decision: .allow),
                                           domain: "duckduckgo.com",
                                           type: .camera),
                                     .init(permission: StoredPermission(id: stored2.id, decision: .deny),
                                           domain: "domainname.org",
                                           type: .popups),
                                     .init(permission: StoredPermission(id: stored3.id, decision: .allow),
                                           domain: "domainname2.org",
                                           type: .externalScheme(scheme: "asdf")),
                                     .init(permission: StoredPermission(id: stored4.id, decision: .deny),
                                           domain: "domainname2.org",
                                           type: .externalScheme(scheme: "dsfg"))])
    }

    func testWhenPermissionIsRemovedThenItShouldntBeLoadedFromStore() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .microphone, decision: .allow)
        let stored2 = try store.add(domain: "otherdomain.com", permissionType: .geolocation, decision: .deny)

        let e = expectation(description: "object removed")
        store.remove(objectWithId: stored2.id) { [store] _ in
            let permissions = try? store.loadPermissions()
            XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, decision: .allow),
                                               domain: "duckduckgo.com",
                                               type: .microphone)])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenPermissionIsUpdatedThenIstLoadedWithNewValue() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .microphone, decision: .allow)
        let stored2 = try store.add(domain: "otherdomain.com", permissionType: .geolocation, decision: .allow)

        let e = expectation(description: "object removed")
        store.update(objectWithId: stored2.id, decision: .deny) { [store] _ in
            let permissions = try? store.loadPermissions()
            XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, decision: .allow),
                                               domain: "duckduckgo.com",
                                               type: .microphone),
                                         .init(permission: StoredPermission(id: stored2.id, decision: .deny),
                                                                            domain: "otherdomain.com",
                                                                            type: .geolocation)])
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenPermissionsAreClearedThenOnlyExceptionsRemain() throws {
        let stored1 = try store.add(domain: "duckduckgo.com", permissionType: .microphone, decision: .allow)
        _=try store.add(domain: "otherdomain.com", permissionType: .geolocation, decision: .allow)
        _=try store.add(domain: "otherdomain2.com", permissionType: .popups, decision: .allow)
        _=try store.add(domain: "otherdomain3.com", permissionType: .externalScheme(scheme: "zoom"), decision: .allow)
        let stored2 = try store.add(domain: "wikipedia.org", permissionType: .camera, decision: .deny)
        _=try store.add(domain: "permission.site", permissionType: .microphone, decision: .deny)
        let stored3 = try store.add(domain: "otherdomain3.com",
                                    permissionType: .externalScheme(scheme: "external-app"),
                                    decision: .deny)

        let e = expectation(description: "store cleared")
        store.clear(except: [stored1, stored2, stored3]) { [store] error in
            XCTAssertNil(error)

            let permissions = try! store.loadPermissions()

            XCTAssertEqual(permissions, [.init(permission: StoredPermission(id: stored1.id, decision: .allow),
                                               domain: "duckduckgo.com",
                                               type: .microphone),
                                         .init(permission: StoredPermission(id: stored2.id, decision: .deny),
                                                                            domain: "wikipedia.org",
                                                                            type: .camera),
                                         .init(permission: StoredPermission(id: stored3.id, decision: .deny),
                                                                            domain: "otherdomain3.com",
                                                                            type: .externalScheme(scheme: "external-app"))])

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}
