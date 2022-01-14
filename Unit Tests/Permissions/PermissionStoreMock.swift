//
//  PermissionStoreMock.swift
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

final class PermissionStoreMock: PermissionStore {
    var permissions = [PermissionEntity]()
    var error: Error?

    enum CallHistoryItem: Equatable {
        case load
        case update(id: NSManagedObjectID, decision: PersistedPermissionDecision?)
        case remove(NSManagedObjectID)
        case add(domain: String, permissionType: PermissionType, decision: PersistedPermissionDecision)
        case clear(exceptions: [StoredPermission])
    }

    var history = [CallHistoryItem]()

    func loadPermissions() throws -> [PermissionEntity] {
        history.append(.load)
        if let error = error {
            throw error
        }
        return permissions
    }

    func update(objectWithId id: NSManagedObjectID, decision: PersistedPermissionDecision?, completionHandler: ((Error?) -> Void)?) {
        history.append(.update(id: id, decision: decision))
        completionHandler?(nil)
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        history.append(.remove(id))
        completionHandler?(nil)
    }

    func add(domain: String, permissionType: PermissionType, decision: PersistedPermissionDecision) throws -> StoredPermission {
        history.append(.add(domain: domain, permissionType: permissionType, decision: decision))
        if let error = error {
            throw error
        }
        return StoredPermission(id: .init(), decision: decision)
    }

    func clear(except: [StoredPermission], completionHandler: ((Error?) -> Void)?) {
        history.append(.clear(exceptions: except))
        completionHandler?(nil)
    }

}
