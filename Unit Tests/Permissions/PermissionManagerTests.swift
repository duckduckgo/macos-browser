//
//  PermissionManagerTests.swift
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

final class PermissionManagerTests: XCTestCase {
    var store: PermissionStoreMock!
    lazy var manager: PermissionManager! = {
        PermissionManager(store: store)
    }()

    override func setUp() {
        store = PermissionStoreMock()
    }

    func testWhenPermissionManagerInitializedThenPermissionsAreLoaded() {
        store.permissions = [.entity1, .entity2]
        let result1 = manager.permission(forDomain: "www." + PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type)
        let result2 = manager.permission(forDomain: PermissionEntity.entity2.domain.dropWWW(),
                                         permissionType: PermissionEntity.entity2.type)
        let result3 = manager.permission(forDomain: "otherdomain.com", permissionType: .microphone)

        XCTAssertEqual(store.history, [.load])
        XCTAssertEqual(result1, true)
        XCTAssertEqual(result2, false)
        XCTAssertNil(result3)
    }

    func testWhenLoadPermissionsFailsThenPermissionsInitializedEmpty() {
        struct SomethingReallyBad: Error {}
        store.error = SomethingReallyBad()
        XCTAssertNil(manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type))

        store.error = nil
        manager.setPermission(true,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .add(domain: PermissionEntity.entity1.domain,
                                            permissionType: PermissionEntity.entity1.type,
                                            allow: true)])
        XCTAssertEqual(result, true)
    }

    func testWhenPermissionUpdatedThenItsValueIsUpdated() {
        store.permissions = [.entity1]
        manager.setPermission(!PermissionEntity.entity1.permission.allow,
                              forDomain: "www." + PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .update(id: PermissionEntity.entity1.permission.id,
                                               allow: !PermissionEntity.entity1.permission.allow)])
        XCTAssertEqual(result, !PermissionEntity.entity1.permission.allow)
    }

    func testWhenPermissionRemovedThenItsValueBecomesNil() {
        store.permissions = [.entity1]
        manager.removePermission(forDomain: PermissionEntity.entity1.domain,
                                 permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .remove(PermissionEntity.entity1.permission.id)])
        XCTAssertNil(result)
    }

    func testWhenNewPermissionIsSetThenItIsSavedAndUpdated() {
        store.permissions = []
        XCTAssertNil(manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type))
        XCTAssertNil(manager.permission(forDomain: PermissionEntity.entity2.domain,
                                        permissionType: PermissionEntity.entity2.type))

        manager.setPermission(true,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)
        manager.setPermission(false,
                              forDomain: PermissionEntity.entity2.domain,
                              permissionType: PermissionEntity.entity2.type)

        let result1 = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type)
        let result2 = manager.permission(forDomain: PermissionEntity.entity2.domain,
                                         permissionType: PermissionEntity.entity2.type)

        XCTAssertEqual(store.history, [.load,
                                       .add(domain: PermissionEntity.entity1.domain,
                                            permissionType: PermissionEntity.entity1.type,
                                            allow: true),
                                       .add(domain: PermissionEntity.entity2.domain.dropWWW(),
                                            permissionType: PermissionEntity.entity2.type,
                                            allow: false)])
        XCTAssertEqual(result1, true)
        XCTAssertEqual(result2, false)
    }

    func testWhenPermissionIsAddedThenSubjectIsPublished() {
        let e = expectation(description: "permission published")
        let c = manager.permissionPublisher.sink { value in
            XCTAssertEqual(value.domain, PermissionEntity.entity1.domain)
            XCTAssertEqual(value.permissionType, PermissionEntity.entity1.type)
            XCTAssertEqual(value.grant, true)
            e.fulfill()
        }

        manager.setPermission(true,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPermissionAddFailsThenSubjectIsPublished() {
        let e = expectation(description: "permission published")
        let c = manager.permissionPublisher.sink { value in
            XCTAssertEqual(value.domain, PermissionEntity.entity1.domain)
            XCTAssertEqual(value.permissionType, PermissionEntity.entity1.type)
            XCTAssertEqual(value.grant, false)
            e.fulfill()
        }

        struct AddingError: Error {}
        store.error = AddingError()
        manager.setPermission(false,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPermissionIsUpdatedThenSubjectIsPublished() {
        store.permissions = [.entity1]

        let e = expectation(description: "permission published")
        let c = manager.permissionPublisher.sink { value in
            XCTAssertEqual(value.domain, PermissionEntity.entity1.domain)
            XCTAssertEqual(value.permissionType, PermissionEntity.entity1.type)
            XCTAssertEqual(value.grant, !PermissionEntity.entity1.permission.allow)
            e.fulfill()
        }

        manager.setPermission(!PermissionEntity.entity1.permission.allow,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPermissionIsRemovedThenSubjectIsPublished() {
        store.permissions = [.entity2]

        let e = expectation(description: "permission published")
        let c = manager.permissionPublisher.sink { value in
            XCTAssertEqual(value.domain, PermissionEntity.entity2.domain.dropWWW())
            XCTAssertEqual(value.permissionType, PermissionEntity.entity2.type)
            XCTAssertNil(value.grant)
            e.fulfill()
        }

        manager.removePermission(forDomain: PermissionEntity.entity2.domain,
                                 permissionType: PermissionEntity.entity2.type)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPermissionsBurnedThenTheyAreCleared() {
        store.permissions = [.entity1, .entity2]

        let fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock())
        fireproofDomains.add(domain: PermissionEntity.entity1.domain)

        manager.burnPermissions(except: fireproofDomains) {}

        XCTAssertEqual(store.history, [.load, .clear(exceptions: [PermissionEntity.entity1.permission])])
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type),
                       true)
        XCTAssertNil(manager.permission(forDomain: PermissionEntity.entity2.domain,
                                        permissionType: PermissionEntity.entity2.type))
    }

}

fileprivate extension PermissionEntity {
    static let entity1 = PermissionEntity(permission: .init(id: .init(), allow: true),
                                          domain: "duckduckgo.com",
                                          type: .camera)
    static let entity2 = PermissionEntity(permission: .init(id: .init(), allow: false),
                                          domain: "www.domain2.com",
                                          type: .microphone)
}
