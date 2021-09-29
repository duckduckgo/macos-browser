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
import os.log

protocol PermissionManagerProtocol: AnyObject {

    typealias PublishedPermission = (domain: String, permissionType: PermissionType, grant: Bool?)
    var permissionPublisher: AnyPublisher<PublishedPermission, Never> { get }

    func permission(forDomain domain: String, permissionType: PermissionType) -> Bool?
    func setPermission(_ permission: Bool, forDomain domain: String, permissionType: PermissionType)
    func removePermission(forDomain domain: String, permissionType: PermissionType)

    func burnPermissions(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void)

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
                self.permissions[entity.domain.dropWWW(), default: [:]][entity.type] = entity.permission
            }
        } catch {
            os_log("PermissionStore: Failed to load permissions", type: .error)
        }
    }

    func permission(forDomain domain: String, permissionType: PermissionType) -> Bool? {
        return permissions[domain.dropWWW()]?[permissionType]?.allow
    }

    func setPermission(_ allow: Bool, forDomain domain: String, permissionType: PermissionType) {
        assert(permissionType.canPersistGrantedDecision || !allow)
        
        let storedPermission: StoredPermission
        let domain = domain.dropWWW()

        defer {
            self.permissionSubject.send( (domain, permissionType, allow) )
        }
        if var oldValue = permissions[domain]?[permissionType] {
            oldValue.allow = allow
            storedPermission = oldValue
            store.update(objectWithId: oldValue.id, allow: allow)
        } else {
            do {
                storedPermission = try store.add(domain: domain, permissionType: permissionType, allow: allow)
            } catch {
                os_log("PermissionStore: Failed to store permission", type: .error)
                return
            }
        }
        self.permissions[domain, default: [:]][permissionType] = storedPermission
    }

    func removePermission(forDomain domain: String, permissionType: PermissionType) {
        let domain = domain.dropWWW()
        guard let oldValue = permissions[domain]?[permissionType] else {
            assertionFailure("PermissionStore: Failed to remove permission")
            return
        }
        permissions[domain]?[permissionType] = nil
        store.remove(objectWithId: oldValue.id)

        self.permissionSubject.send( (domain, permissionType, nil) )
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

}
