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

protocol PermissionStore: AnyObject {
    func loadPermissions() throws -> [PermissionEntity]
    func update(objectWithId id: NSManagedObjectID, decision: PersistedPermissionDecision?, completionHandler: ((Error?) -> Void)?)
    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?)
    func add(domain: String, permissionType: PermissionType, decision: PersistedPermissionDecision) throws -> StoredPermission

    func clear(except: [StoredPermission], completionHandler: ((Error?) -> Void)?)
}

extension PermissionStore {
    func update(objectWithId id: NSManagedObjectID, decision: PersistedPermissionDecision?) {
        update(objectWithId: id, decision: decision, completionHandler: nil)
    }
    func remove(objectWithId id: NSManagedObjectID) {
        remove(objectWithId: id, completionHandler: nil)
    }
    func clear(except exceptions: [StoredPermission]) {
        clear(except: exceptions, completionHandler: nil)
    }
}

final class LocalPermissionStore: PermissionStore {
    private var _context: NSManagedObjectContext??
    private var context: NSManagedObjectContext? {
        if case .none = _context {
#if DEBUG
            guard NSApp.runType.requiresEnvironment else {
                _context = .some(.none)
                return .none
            }
#endif
            _context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Permissions")
        }
        return _context!
    }

    init() {
    }

    init(context: NSManagedObjectContext) {
        self._context = .some(context)
    }

    func loadPermissions() throws -> [PermissionEntity] {
        guard let context = context else { return [] }

        var entities = [PermissionEntity]()
        var coreDataError: Error?

        context.performAndWait {
            let fetchRequest = NSFetchRequest<PermissionManagedObject>(entityName: PermissionManagedObject.className())
            fetchRequest.returnsObjectsAsFaults = false

            do {
                let permissionManagedObjects = try context.fetch(fetchRequest)
                entities = permissionManagedObjects.compactMap(PermissionEntity.init(managedObject:))
            } catch {
                coreDataError = error
            }
        }

        if let coreDataError = coreDataError {
            throw coreDataError
        }

        return entities
    }

    func update(objectWithId id: NSManagedObjectID, decision: PersistedPermissionDecision?, completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            guard let managedObject = try? context.existingObject(with: id) as? PermissionManagedObject else {
                assertionFailure("PermissionStore: Failed to get PermissionManagedObject from the context")
                struct PermissionManagedObjectNotFound: Error {}
                mainQueueCompletion(error: PermissionManagedObjectNotFound())
                return
            }

            if let decision = decision {
                managedObject.decision = decision
            } else {
                context.delete(managedObject)
            }

            do {
                try context.save()
                mainQueueCompletion(error: nil)
            } catch {
                assertionFailure("PermissionStore: Saving of context failed")
                mainQueueCompletion(error: error)
            }
        }
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        update(objectWithId: id, decision: nil, completionHandler: completionHandler)
    }

    func clear(except exceptions: [StoredPermission], completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PermissionManagedObject.className())
            deleteRequest.predicate = NSPredicate(format: "NOT (self IN %@)",
                                                  exceptions.map { context.object(with: $0.id) })
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                mainQueueCompletion(error: nil)
            } catch {
                mainQueueCompletion(error: error)
            }
        }
    }

    private func performAdd(domain: String,
                            permissionType: PermissionType,
                            decision: PersistedPermissionDecision) -> Result<NSManagedObjectID, Error>? {
        guard let context = context else { return nil }

        var result: Result<NSManagedObjectID, Error>?
        context.performAndWait { [context] in
            let entityName = PermissionManagedObject.className()
            guard let managedObject = NSEntityDescription
                    .insertNewObject(forEntityName: entityName, into: context) as? PermissionManagedObject
            else { return }

            managedObject.domainEncrypted = domain as NSString
            managedObject.permissionType = permissionType.rawValue
            managedObject.decision = decision

            do {
                try context.save()
                result = .success(managedObject.objectID)
            } catch {
                result = .failure(error)
            }
        }
        return result
    }

    func add(domain: String, permissionType: PermissionType, decision: PersistedPermissionDecision) throws -> StoredPermission {
        let result = performAdd(domain: domain, permissionType: permissionType, decision: decision)
        switch result {
        case .success(let id):
            return StoredPermission(id: id, decision: decision)
        case .failure(let error):
            throw error
        case .none:
            struct InvalidManagedObject: Error {}
            throw InvalidManagedObject()
        }
    }

}
