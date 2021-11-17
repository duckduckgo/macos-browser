//
//  FireproofDomainsStore.swift
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
import CoreData
import Cocoa
import os.log

protocol FireproofDomainsStore: AnyObject {
    func loadFireproofDomains() throws -> [String: NSManagedObjectID]

    func remove(objectWithId: NSManagedObjectID, completionHandler: ((Error?) -> Void)?)
    func add(fireproofDomain: String) throws -> NSManagedObjectID
    func add(fireproofDomains: [String]) throws -> [String: NSManagedObjectID]

    func clear(completionHandler: ((Error?) -> Void)?)
}

extension FireproofDomainsStore {
    func remove(objectWithId id: NSManagedObjectID) {
        remove(objectWithId: id, completionHandler: nil)
    }
    func clear() {
        clear(completionHandler: nil)
    }
}

final class LocalFireproofDomainsStore: FireproofDomainsStore {
    private var _context: NSManagedObjectContext??
    private var context: NSManagedObjectContext? {
        if case .none = _context {
#if DEBUG
            if AppDelegate.isRunningTests {
                _context = .some(.none)
                return .none
            }
#endif
            _context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "FireproofDomains")
        }
        return _context!
    }

    init() {
    }

    init(context: NSManagedObjectContext) {
        self._context = .some(context)
    }

    func loadFireproofDomains() throws -> [String: NSManagedObjectID] {
        guard let context = context else { return [:] }

        var result = [String: NSManagedObjectID]()
        var coreDataError: Error?

        context.performAndWait {
            let fetchRequest = NSFetchRequest<FireproofDomainManagedObject>(entityName: FireproofDomainManagedObject.className())
            fetchRequest.returnsObjectsAsFaults = false

            do {
                let managedObjects = try context.fetch(fetchRequest)
                result = managedObjects.reduce(into: [:]) {
                    guard let domain = $1.domainEncrypted as? String else { return }
                    $0[domain] = $1.objectID
                }
            } catch {
                coreDataError = error
            }
        }

        if let coreDataError = coreDataError {
            throw coreDataError
        }

        return result
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            guard let managedObject = try? context.existingObject(with: id) as? FireproofDomainManagedObject else {
                assertionFailure("LocalFireproofDomainsStore: Failed to get FireproofDomainManagedObject from the context")
                struct FireproofDomainManagedObjectNotFound: Error {}
                mainQueueCompletion(error: FireproofDomainManagedObjectNotFound())
                return
            }

            context.delete(managedObject)

            do {
                try context.save()
                mainQueueCompletion(error: nil)
            } catch {
                assertionFailure("LocalFireproofDomainsStore: Saving of context failed")
                mainQueueCompletion(error: error)
            }
        }
    }

    func clear(completionHandler: ((Error?) -> Void)?) {
        guard let context = context else { return }
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: FireproofDomainManagedObject.className())
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

    private func performAdd(domains: [String]) -> Result<[String: NSManagedObjectID], Error>? {
        guard let context = context else { return nil }

        var result: Result<[String: NSManagedObjectID], Error>?
        context.performAndWait { [context] in
            let entityName = FireproofDomainManagedObject.className()

            var added = [String: NSManagedObjectID]()
            for domain in domains {
                guard let managedObject = NSEntityDescription
                    .insertNewObject(forEntityName: entityName, into: context) as? FireproofDomainManagedObject
                else { continue }

                managedObject.domainEncrypted = domain as NSString
                added[domain] = managedObject.objectID
            }
            guard !added.isEmpty else { return }

            do {
                try context.save()
                result = .success(added)
            } catch {
                result = .failure(error)
            }
        }
        return result
    }

    func add(fireproofDomains: [String]) throws -> [String: NSManagedObjectID] {
        let result = performAdd(domains: fireproofDomains)
        switch result {
        case .success(let dict):
            return dict
        case .failure(let error):
            throw error
        case .none:
            struct InvalidManagedObject: Error {}
            throw InvalidManagedObject()
        }
    }

    func add(fireproofDomain: String) throws -> NSManagedObjectID {
        let result = performAdd(domains: [fireproofDomain])
        switch result {
        case .failure(let error):
            throw error
        case .success(let dict):
            guard let id = dict.first?.value else { fallthrough }
            return id
        case .none:
            struct InvalidManagedObject: Error {}
            throw InvalidManagedObject()
        }
    }

}
