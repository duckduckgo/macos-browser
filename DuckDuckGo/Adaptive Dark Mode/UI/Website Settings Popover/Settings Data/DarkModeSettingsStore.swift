//
//  DarkModeSettingsStore.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

typealias DarkModeExceptionDomainStore = CoreDataStore<DarkModeExceptionDomain>

final class DarkModeSettingsStore {
    static let shared = DarkModeSettingsStore()
    private let store: DarkModeExceptionDomainStore
    private var domainsCache = [String]()
  
    private typealias ExceptionDomainsContainer = KeySetDictionary<String, NSManagedObjectID>
    private let queue = DispatchQueue(label: "exception.darkmode.domains.queue")
    lazy private var excludedDomains: ExceptionDomainsContainer = loadExceptionDomains()
    
    private var excludedDomainValues: Set<String> {
        queue.sync {
            excludedDomains.keys
        }
    }
    
    init(store: DarkModeExceptionDomainStore = DarkModeExceptionDomainStore(tableName: "DarkModeSettings")) {
        self.store = store
    }
    
    private func loadExceptionDomains() -> ExceptionDomainsContainer {
        do {
            return try store.load(into: [:]) { $0[$1.value] = $1.id }
        } catch {
            return [:]
        }
    }
    
    private func modifyExceptionDomains<T>(_ modify: (inout ExceptionDomainsContainer) throws -> T) rethrows -> T {
        try queue.sync {
            try modify(&excludedDomains)
        }
    }
    
    func addDomainToExceptionList(domain: String) {
        guard !isDomainOnExceptionList(domain: domain) else { return }
        
        do {
            let id = try store.add(domain)
            modifyExceptionDomains { $0[domain] = id }
        } catch {
            assertionFailure("could not add domain \(domain): \(error)")
        }
    }
    
    func removeDomainFromExceptionList(domain: String) {
        guard let id = modifyExceptionDomains({ $0.removeValue(forKey: domain) }),
        !isDomainOnExceptionList(domain: domain) else {
            assertionFailure("domain \(domain) not found")
            return
        }
        store.remove(objectWithId: id) { error in
            if let error = error {
                assertionFailure("DarkModeExceptionDomainStore: Failed to remove Domain: \(error)")
                return
            }
        }
    }
    
    func isDomainOnExceptionList(domain: String) -> Bool {
        excludedDomainValues.contains(domain)
    }
}

extension DarkModeExceptionDomain: ValueRepresentableManagedObject {

    func valueRepresentation() -> String? {
        self.domainEncrypted as? String
    }

    func update(with domain: String) {
        self.domainEncrypted = domain as NSString
    }

}
