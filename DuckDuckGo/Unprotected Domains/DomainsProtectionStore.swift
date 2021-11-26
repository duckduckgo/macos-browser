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

protocol UnprotectedDomains: AnyObject {
    func isHostUnprotected(_ domain: String) -> Bool
    func disableProtection(forDomain domain: String)
    func enableProtection(forDomain domain: String)
}

typealias UnprotectedDomainsStore = CoreDataStore<UnprotectedDomainManagedObject>
final class LocalUnprotectedDomains: UnprotectedDomains {

    static let shared = LocalUnprotectedDomains()

    private let store: UnprotectedDomainsStore

    @UserDefaultsWrapper(key: .unprotectedDomains, defaultValue: nil)
    private var legacyUserDefaultsUnprotectedDomainsData: Data?

    lazy private var unprotectedDomainsToIds: [String: NSManagedObjectID] = loadUnprotectedDomains()

    var unprotectedDomains: [String] {
        Array(unprotectedDomainsToIds.keys)
    }

    init(store: UnprotectedDomainsStore = UnprotectedDomainsStore(tableName: "UnprotectedDomains")) {
        self.store = store
    }

    private func loadUnprotectedDomains() -> [String: NSManagedObjectID] {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            if let data = legacyUserDefaultsUnprotectedDomainsData,
               var domains = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSet.self, from: data) as? Set<String>,
               !domains.isEmpty {

                domains = Set(domains.map { $0.dropWWW() })
                var result = [String: NSManagedObjectID]()
                do {
                    result = try store.add(domains).reduce(into: [:]) { $0[$1.value] = $1.id }
                    self.legacyUserDefaultsUnprotectedDomainsData = nil
                } catch {}

                return result
            }

            return try store.load(into: [:]) { $0[$1.value] = $1.id }
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
            let id = try store.add(domainWithoutWWW)
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

extension UnprotectedDomainManagedObject: ValueRepresentableManagedObject {

    func valueRepresentation() -> String? {
        self.domainEncrypted as? String
    }

    func update(with domain: String) {
        self.domainEncrypted = domain as NSString
    }

}
