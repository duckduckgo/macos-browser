//
//  StoredPermission.swift
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

struct StoredPermission: Equatable {
    let id: NSManagedObjectID
    var allow: Bool
}

struct PermissionEntity: Equatable {
    let permission: StoredPermission
    let domain: String
    let type: PermissionType

    init(permission: StoredPermission, domain: String, type: PermissionType) {
        self.permission = permission
        self.domain = domain
        self.type = type
    }

    init?(managedObject: PermissionManagedObject) {
        guard let domain = managedObject.domainEncrypted as? String,
              let permissionTypeString = managedObject.permissionType,
              let permissionType = PermissionType(rawValue: permissionTypeString) else {
            assertionFailure("\(#file): Failed to create PermissionEntity from PermissionManagedObject")
            return nil
        }

        self.permission = StoredPermission(id: managedObject.objectID, allow: managedObject.allow)
        self.domain = domain
        self.type = permissionType
    }

}
