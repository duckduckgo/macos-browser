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
import os.log

protocol PermissionManagerProtocol: AnyObject {

    func permission(forDomain domain: String, permissionType: PermissionType) -> Bool?
    func setPermission(_ permission: Bool, forDomain domain: String, permissionType: PermissionType)
    func removePermission(forDomain domain: String, permissionType: PermissionType)

}

final class PermissionManager: PermissionManagerProtocol {

    static let shared = PermissionManager()

    private let store: PermissionStore
    private var permissions = [String: [PermissionType: StoredPermission]]()

    init(store: PermissionStore = .init()) {
        self.store = store
        loadPermissions()
    }

    private func loadPermissions() {
        do {
            let entities = try store.loadPermissions()
            for entity in entities {
                self.permissions[entity.domain, default: [:]][entity.type] = entity.permission
            }
        } catch {
            assertionFailure("PermissionStore: Failed to load permissions \(String(describing: error))")
        }
    }

    func permission(forDomain domain: String, permissionType: PermissionType) -> Bool? {
        return permissions[domain.dropWWW()]?[permissionType]?.allow
    }

    func setPermission(_ allow: Bool, forDomain domain: String, permissionType: PermissionType) {
        let storedPermission: StoredPermission
        let domain = domain.dropWWW()
        if var oldValue = permissions[domain]?[permissionType] {
            oldValue.allow = allow
            storedPermission = oldValue
            store.update(objectWithId: oldValue.id, allow: allow)
        } else {
            do {
                storedPermission = try store.add(domain: domain, permissionType: permissionType, allow: allow)
            } catch {
                assertionFailure("PermissionStore: Failed to store permission: \(error)")
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
    }

}
