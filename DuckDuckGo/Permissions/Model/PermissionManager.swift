//
//  PermissionManager.swift
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
import Combine
import Common
import os.log

protocol PermissionManagerProtocol: AnyObject {

    typealias PublishedPermission = (domain: String, permissionType: PermissionType, decision: PersistedPermissionDecision)
    var permissionPublisher: AnyPublisher<PublishedPermission, Never> { get }

    func permission(forDomain domain: String, permissionType: PermissionType) -> PersistedPermissionDecision
    func setPermission(_ decision: PersistedPermissionDecision, forDomain domain: String, permissionType: PermissionType)

    func burnPermissions(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void)
    func burnPermissions(of baseDomains: Set<String>, tld: TLD, completion: @escaping () -> Void)

}

final class PermissionManager: PermissionManagerProtocol {

    static let shared = PermissionManager()

    private let store: PermissionStore
    private var permissions = [String: [PermissionType: StoredPermission]]()

    private let permissionSubject = PassthroughSubject<PublishedPermission, Never>()
    var permissionPublisher: AnyPublisher<PublishedPermission, Never> { permissionSubject.eraseToAnyPublisher() }

    init(store: PermissionStore = LocalPermissionStore()) {
        self.store = store
        loadPermissions()
    }

    private func loadPermissions() {
        do {
            let entities = try store.loadPermissions()
            for entity in entities {
                self.set(entity.permission, forDomain: entity.domain.droppingWwwPrefix(), permissionType: entity.type)
            }
        } catch {
            Logger.general.error("PermissionStore: Failed to load permissions")
        }
    }

    private func set(_ permission: StoredPermission, forDomain domain: String, permissionType: PermissionType) {
        self.permissions[domain, default: [:]][permissionType] = permission
        persistedPermissionTypes.insert(permissionType)
    }

    private(set) var persistedPermissionTypes = Set<PermissionType>()

    func permission(forDomain domain: String, permissionType: PermissionType) -> PersistedPermissionDecision {
        return permissions[domain.droppingWwwPrefix()]?[permissionType]?.decision ?? .ask
    }

    func hasPermissionPersisted(forDomain domain: String, permissionType: PermissionType) -> Bool {
        return permissions[domain.droppingWwwPrefix()]?[permissionType] != nil
    }

    func setPermission(_ decision: PersistedPermissionDecision, forDomain domain: String, permissionType: PermissionType) {
        assert(permissionType.canPersistGrantedDecision || decision != .allow)
        assert(permissionType.canPersistDeniedDecision || decision != .deny)

        let storedPermission: StoredPermission
        let domain = domain.droppingWwwPrefix()
        guard self.permission(forDomain: domain, permissionType: permissionType) != decision else { return }

        defer {
            self.permissionSubject.send( (domain, permissionType, decision) )
        }
        if var oldValue = permissions[domain]?[permissionType] {
            oldValue.decision = decision
            storedPermission = oldValue
            store.update(objectWithId: oldValue.id, decision: decision)
        } else {
            do {
                storedPermission = try store.add(domain: domain, permissionType: permissionType, decision: decision)
            } catch {
                Logger.general.error("PermissionStore: Failed to store permission")
                return
            }
        }
        self.set(storedPermission, forDomain: domain, permissionType: permissionType)
    }

    func burnPermissions(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        permissions = permissions.filter {
            fireproofDomains.isFireproof(fireproofDomain: $0.key)
        }
        store.clear(except: permissions.values.reduce(into: [StoredPermission](), {
            $0.append(contentsOf: $1.values)
        }), completionHandler: { _ in
            completion()
        })
    }

    func burnPermissions(of baseDomains: Set<String>, tld: TLD, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        permissions = permissions.filter { permission in
            let baseDomain = tld.eTLDplus1(permission.key) ?? ""
            return !baseDomains.contains(baseDomain)
        }
        store.clear(except: permissions.values.reduce(into: [StoredPermission](), {
            $0.append(contentsOf: $1.values)
        }), completionHandler: { _ in
            completion()
        })
    }

}
