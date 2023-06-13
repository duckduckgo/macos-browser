//
//  PermissionManagerMock.swift
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
@testable import DuckDuckGo_Privacy_Browser
import Combine
import Common

final class PermissionManagerMock: PermissionManagerProtocol {

    var permissionSubject = PassthroughSubject<PublishedPermission, Never>()
    var permissionPublisher: AnyPublisher<PublishedPermission, Never> {
        permissionSubject.eraseToAnyPublisher()
    }

    var savedPermissions = [String: [PermissionType: Bool]]()

    func permission(forDomain domain: String, permissionType: PermissionType) -> PersistedPermissionDecision {
        guard let allow = savedPermissions[domain.droppingWwwPrefix()]?[permissionType] else { return .ask }
        return PersistedPermissionDecision(allow: allow, isRemoved: false)
    }

    func setPermission(_ decision: PersistedPermissionDecision, forDomain domain: String, permissionType: PermissionType) {
        savedPermissions[domain.droppingWwwPrefix(), default: [:]][permissionType] = decision == .ask ? nil : decision.boolValue
    }

    func removePermission(forDomain domain: String, permissionType: PermissionType) {
        savedPermissions[domain.droppingWwwPrefix(), default: [:]][permissionType] = nil
    }

    var burnPermissionsCalled = false
    func burnPermissions(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        savedPermissions = savedPermissions.filter { fireproofDomains.isFireproof(fireproofDomain: $0.key) }
        burnPermissionsCalled = true
        completion()
    }

    var burnPermissionsOfDomainsCalled = false
    func burnPermissions(of baseDomains: Set<String>, tld: Common.TLD, completion: @escaping () -> Void) {
        burnPermissionsOfDomainsCalled = true
        completion()
    }

}
