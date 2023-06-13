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
        let result2 = manager.permission(forDomain: PermissionEntity.entity2.domain.droppingWwwPrefix(),
                                         permissionType: PermissionEntity.entity2.type)
        let result3 = manager.permission(forDomain: "otherdomain.com", permissionType: .microphone)

        XCTAssertEqual(store.history, [.load])
        XCTAssertEqual(result1, .allow)
        XCTAssertEqual(result2, .deny)
        XCTAssertEqual(result3, .ask)
    }

    func testWhenLoadPermissionsFailsThenPermissionsInitializedEmpty() {
        struct SomethingReallyBad: Error {}
        store.error = SomethingReallyBad()
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity1.domain, permissionType: PermissionEntity.entity1.type),
                       .ask)

        store.error = nil
        manager.setPermission(.allow,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .add(domain: PermissionEntity.entity1.domain,
                                            permissionType: PermissionEntity.entity1.type,
                                            decision: .allow)])
        XCTAssertEqual(result, .allow)
    }

    func testWhenPermissionUpdatedThenItsValueIsUpdated() {
        store.permissions = [.entity1]
        manager.setPermission(.deny,
                              forDomain: "www." + PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .update(id: PermissionEntity.entity1.permission.id,
                                               decision: .deny)])
        XCTAssertEqual(result, .deny)
    }

    func testWhenPermissionRemovedThenItsValueBecomesNil() {
        store.permissions = [.entity1]
        manager.setPermission(.ask, forDomain: PermissionEntity.entity1.domain, permissionType: PermissionEntity.entity1.type)

        let result = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                        permissionType: PermissionEntity.entity1.type)

        XCTAssertEqual(store.history, [.load,
                                       .update(id: PermissionEntity.entity1.permission.id, decision: .ask)])
        XCTAssertEqual(result, .ask)
    }

    func testWhenNewPermissionIsSetThenItIsSavedAndUpdated() {
        store.permissions = []
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity1.domain, permissionType: PermissionEntity.entity1.type),
                       .ask)
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity2.domain, permissionType: PermissionEntity.entity2.type),
                     .ask)

        manager.setPermission(.allow,
                              forDomain: PermissionEntity.entity1.domain,
                              permissionType: PermissionEntity.entity1.type)
        manager.setPermission(.deny,
                              forDomain: PermissionEntity.entity2.domain,
                              permissionType: PermissionEntity.entity2.type)

        let result1 = manager.permission(forDomain: PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type)
        let result2 = manager.permission(forDomain: PermissionEntity.entity2.domain,
                                         permissionType: PermissionEntity.entity2.type)

        XCTAssertEqual(store.history, [.load,
                                       .add(domain: PermissionEntity.entity1.domain,
                                            permissionType: PermissionEntity.entity1.type,
                                            decision: .allow),
                                       .add(domain: PermissionEntity.entity2.domain.droppingWwwPrefix(),
                                            permissionType: PermissionEntity.entity2.type,
                                            decision: .deny)])
        XCTAssertEqual(result1, .allow)
        XCTAssertEqual(result2, .deny)
    }

    func testWhenPermissionIsAddedThenSubjectIsPublished() {
        let e = expectation(description: "permission published")
        let c = manager.permissionPublisher.sink { value in
            XCTAssertEqual(value.domain, PermissionEntity.entity1.domain)
            XCTAssertEqual(value.permissionType, PermissionEntity.entity1.type)
            XCTAssertEqual(value.decision, .allow)
            e.fulfill()
        }

        manager.setPermission(.allow,
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
            XCTAssertEqual(value.decision, .deny)
            e.fulfill()
        }

        struct AddingError: Error {}
        store.error = AddingError()
        manager.setPermission(.deny,
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
            XCTAssertEqual(value.decision, .deny)
            e.fulfill()
        }

        manager.setPermission(.deny,
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
            XCTAssertEqual(value.domain, PermissionEntity.entity2.domain.droppingWwwPrefix())
            XCTAssertEqual(value.permissionType, PermissionEntity.entity2.type)
            XCTAssertEqual(value.decision, .ask)
            e.fulfill()
        }

        manager.setPermission(.ask,
                              forDomain: PermissionEntity.entity2.domain,
                              permissionType: PermissionEntity.entity2.type)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPermissionsBurnedThenTheyAreCleared() {
        store.permissions = [.entity1, .entity2]

        let fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock(), tld: ContentBlocking.shared.tld)
        fireproofDomains.add(domain: PermissionEntity.entity1.domain)

        manager.burnPermissions(except: fireproofDomains) {}

        XCTAssertEqual(store.history, [.load, .clear(exceptions: [PermissionEntity.entity1.permission])])
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type),
                       .allow)
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity2.domain, permissionType: PermissionEntity.entity2.type),
                     .ask)
    }

    func testWhenPermissionsForDomainsBurnedThenTheyAreCleared() {
        store.permissions = [.entity1, .entity2]

        let fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock(), tld: ContentBlocking.shared.tld)
        fireproofDomains.add(domain: PermissionEntity.entity1.domain)

        manager.burnPermissions(of: [PermissionEntity.entity2.domain.droppingWwwPrefix()], tld: ContentBlocking.shared.tld) {}

        XCTAssertEqual(store.history, [.load, .clear(exceptions: [PermissionEntity.entity1.permission])])
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity1.domain,
                                         permissionType: PermissionEntity.entity1.type),
                       .allow)
        XCTAssertEqual(manager.permission(forDomain: PermissionEntity.entity2.domain, permissionType: PermissionEntity.entity2.type),
                     .ask)
    }

}

fileprivate extension PermissionEntity {
    static let entity1 = PermissionEntity(permission: .init(id: .init(), decision: .allow),
                                          domain: "duckduckgo.com",
                                          type: .camera)
    static let entity2 = PermissionEntity(permission: .init(id: .init(), decision: .deny),
                                          domain: "www.domain2.com",
                                          type: .microphone)
}
