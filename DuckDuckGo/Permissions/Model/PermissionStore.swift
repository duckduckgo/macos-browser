//
//  PermissionStore.swift
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

final class PermissionStore {
    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Permissions")

    init() {
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadPermissions() throws -> [PermissionEntity] {
        let fetchRequest = NSFetchRequest<PermissionManagedObject>(entityName: PermissionManagedObject.className())

        fetchRequest.returnsObjectsAsFaults = false

        let permissionManagedObjects = try context.fetch(fetchRequest)
        let entities = permissionManagedObjects.compactMap(PermissionEntity.init(managedObject:))

        return entities
    }

    func update(objectWithId id: NSManagedObjectID, allow: Bool?) {
        context.perform { [context] in
            guard let managedObject = try? context.existingObject(with: id) as? PermissionManagedObject else {
                assertionFailure("PermissionStore: Failed to get PermissionManagedObject from the context")
                return
            }

            if let allow = allow {
                managedObject.allow = allow
            } else {
                context.delete(managedObject)
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("PermissionStore: Saving of context failed")
            }
        }
    }

    func remove(objectWithId id: NSManagedObjectID) {
        update(objectWithId: id, allow: nil)
    }

    func add(domain: String, permissionType: PermissionType, allow: Bool) throws -> StoredPermission {
        var result: Result<NSManagedObjectID, Error>?
        context.performAndWait { [context] in

            guard let managedObject = NSEntityDescription.insertNewObject(forEntityName: PermissionManagedObject.className(),
                                                                          into: context) as? PermissionManagedObject
            else { return }

            managedObject.domainEncrypted = domain as NSString
            managedObject.permissionType = permissionType.rawValue
            managedObject.allow = allow

            do {
                try self.context.save()
                result = .success(managedObject.objectID)
            } catch {
                result = .failure(error)
            }
        }

        switch result {
        case .success(let id):
            return StoredPermission(id: id, allow: allow)
        case .failure(let error):
            throw error
        case .none:
            struct InvalidManagedObject: Error {}
            throw InvalidManagedObject()
        }
    }

}
