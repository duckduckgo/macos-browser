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
import BrowserServicesKit

typealias UnprotectedDomainsStore = CoreDataStore<UnprotectedDomainManagedObject>
final class LocalUnprotectedDomains {

    static let shared = LocalUnprotectedDomains()

    private let store: UnprotectedDomainsStore

    @UserDefaultsWrapper(key: .unprotectedDomains, defaultValue: nil)
    private var legacyUserDefaultsUnprotectedDomainsData: Data?

    private let queue = DispatchQueue(label: "unprotected.domains.queue")
    lazy private var _unprotectedDomainsToIds: [String: NSManagedObjectID] = loadUnprotectedDomains()

    private var unprotectedDomainsToIds: [String: NSManagedObjectID] {
        queue.sync {
            _unprotectedDomainsToIds
        }
    }

    private func modifyUnprotectedDomainsToIds<T>(_ modify: (inout [String: NSManagedObjectID]) throws -> T) rethrows -> T {
        try queue.sync {
            try modify(&_unprotectedDomainsToIds)
        }
    }

    init(store: UnprotectedDomainsStore = UnprotectedDomainsStore(tableName: "UnprotectedDomains")) {
        self.store = store
    }

    private func loadUnprotectedDomains() -> [String: NSManagedObjectID] {
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
        return unprotectedDomainsToIds[domain.dropWWW()] != nil
    }

    func disableProtection(forDomain domain: String) {
        let domainWithoutWWW = domain.dropWWW()
        do {
            let id = try store.add(domainWithoutWWW)
            modifyUnprotectedDomainsToIds { $0[domainWithoutWWW] = id }
        } catch {
            assertionFailure("could not add unprotected domain \(domain): \(error)")
        }
    }

    func enableProtection(forDomain domain: String, completionHandler: ((Error?) -> Void)?) {
        let domainWithoutWWW = domain.dropWWW()
        guard let id = unprotectedDomainsToIds[domainWithoutWWW] else {
            assertionFailure("unprotected domain \(domain) not found")
            return
        }
        store.remove(objectWithId: id) { [weak self] error in
            defer { completionHandler?(error) }
            guard error == nil else {
                os_log("UnprotectedDomainStore: Failed to remove Unprotected Domain", type: .error)
                return
            }
            self?.modifyUnprotectedDomainsToIds {
                $0.updateInPlace(key: domainWithoutWWW) {
                    guard $0 == id else { return }
                    $0 = nil
                }
            }

        }
    }

}

extension LocalUnprotectedDomains: DomainsProtectionStore {

    var unprotectedDomains: Set<String> {
        Set(unprotectedDomainsToIds.keys)
    }

    func enableProtection(forDomain domain: String) {
        enableProtection(forDomain: domain, completionHandler: nil)
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
