//
//  LocalUnprotectedDomains.swift
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
import Common
import Foundation
import CoreData
import BrowserServicesKit
import os.log

typealias UnprotectedDomainsStore = CoreDataStore<UnprotectedDomainManagedObject>
final class LocalUnprotectedDomains: DomainsProtectionStore {

    static let shared = LocalUnprotectedDomains()

    private let store: UnprotectedDomainsStore

    @UserDefaultsWrapper(key: .unprotectedDomains, defaultValue: nil)
    private var legacyUserDefaultsUnprotectedDomainsData: Data?

    private let queue = DispatchQueue(label: "unprotected.domains.queue")

    private typealias UnprotectedDomainsContainer = KeySetDictionary<String, NSManagedObjectID>
    lazy private var _unprotectedDomains: UnprotectedDomainsContainer = loadUnprotectedDomains()

    private var unprotectedDomainsToIds: UnprotectedDomainsContainer {
        queue.sync {
            _unprotectedDomains
        }
    }

    var unprotectedDomains: Set<String> {
        queue.sync {
            _unprotectedDomains.keys
        }
    }

    private func modifyUnprotectedDomains<T>(_ modify: (inout UnprotectedDomainsContainer) throws -> T) rethrows -> T {
        try queue.sync {
            try modify(&_unprotectedDomains)
        }
    }

    init(store: UnprotectedDomainsStore = UnprotectedDomainsStore(tableName: "UnprotectedDomains")) {
        self.store = store
    }

    private func loadUnprotectedDomains() -> UnprotectedDomainsContainer {
        do {
            if let data = legacyUserDefaultsUnprotectedDomainsData,
               let domains = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSet.self, from: data) as? Set<String>,
               !domains.isEmpty {

                var result = UnprotectedDomainsContainer()
                do {
                    result = try store.add(domains).reduce(into: [:]) { $0[$1.value] = $1.id }
                    self.legacyUserDefaultsUnprotectedDomainsData = nil
                } catch {}

                return result
            }

            return try store.load(into: [:]) { $0[$1.value] = $1.id }
        } catch {
            Logger.general.error("UnprotectedDomainStore: Failed to load Unprotected Domains")
            return [:]
        }
    }

    func disableProtection(forDomain domain: String) {
        do {
            let id = try store.add(domain)
            modifyUnprotectedDomains { $0[domain] = id }
        } catch {
            assertionFailure("could not add unprotected domain \(domain): \(error)")
        }
    }

    func enableProtection(forDomain domain: String) {
        guard let id = modifyUnprotectedDomains({ $0.removeValue(forKey: domain) }) else {
            assertionFailure("unprotected domain \(domain) not found")
            return
        }
        store.remove(objectWithId: id) { error in
            if let error = error {
                assertionFailure("UnprotectedDomainStore: Failed to remove Unprotected Domain: \(error)")
                return
            }
        }
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
