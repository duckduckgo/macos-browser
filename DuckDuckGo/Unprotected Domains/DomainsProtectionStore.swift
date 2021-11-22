//
//  DomainsProtectionStore.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import os.log

protocol DomainsProtectionStore: AnyObject {
    func isHostUnprotected(_ domain: String) -> Bool
    func disableProtection(forDomain domain: String)
    func enableProtection(forDomain domain: String)
}

final class LocalDomainsProtectionStore: DomainsProtectionStore {

    static let shared = LocalDomainsProtectionStore()
    private let store: DataStore

    @UserDefaultsWrapper(key: .unprotectedDomains, defaultValue: nil)
    private var legacyUserDefaultsUnprotectedDomainsData: Data?

    lazy private var unprotectedDomainsToIds: [String: NSManagedObjectID] = loadUnprotectedDomains()

    var unprotectedDomains: [String] {
        Array(unprotectedDomainsToIds.keys)
    }

    init(store: DataStore = CoreDataStore(tableName: "UnprotectedDomains")) {
        self.store = store
    }

    private func loadUnprotectedDomains() -> [String: NSManagedObjectID] {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            if let data = legacyUserDefaultsUnprotectedDomainsData,
               let domains = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSet.self, from: data) as? Set<String>,
               !domains.isEmpty {

                var result = [String: NSManagedObjectID]()
                do {
                    let added = try store.add(domains) { (object: UnprotectedDomainManagedObject, domain) in
                        object.update(withDomain: domain.dropWWW())
                    }
                    for (domain, id) in added {
                        result[domain.dropWWW()] = id
                    }

                    self.legacyUserDefaultsUnprotectedDomainsData = nil
                } catch {}

                return result
            }

            return try store.load(into: [:]) { (result, object: UnprotectedDomainManagedObject) in
                guard let domain = object.domainEncrypted as? String else { return }
                result[domain] = object.objectID
            }
        } catch {
            os_log("UnprotectedDomainStore: Failed to load Unprotected Domains", type: .error)
            return [:]
        }
    }

    func isHostUnprotected(_ domain: String) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return unprotectedDomainsToIds[domain.dropWWW()] != nil
    }

    func disableProtection(forDomain domain: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        let domainWithoutWWW = domain.dropWWW()
        do {
            let id = try store.add(domainWithoutWWW, using: UnprotectedDomainManagedObject.update)
            unprotectedDomainsToIds[domainWithoutWWW] = id
        } catch {
            assertionFailure("could not add unprotected domain \(domain): \(error)")
        }
    }

    func enableProtection(forDomain domain: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        let domainWithoutWWW = domain.dropWWW()
        guard let id = unprotectedDomainsToIds[domainWithoutWWW] else {
            assertionFailure("unprotected domain \(domain) not found")
            return
        }
        store.remove(objectWithId: id)
    }

}

extension UnprotectedDomainManagedObject {
    func update(withDomain domain: String) {
        self.domainEncrypted = domain as NSString
    }
}
