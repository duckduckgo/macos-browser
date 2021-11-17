//
//  FireproofDomains.swift
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
import os.log

internal class FireproofDomains {

    enum Constants {
        static let allowedDomainsChangedNotification = Notification.Name("allowedDomainsChangedNotification")
        static let newFireproofDomainNotification = Notification.Name("newFireproofedDomainNotification")
        static let newFireproofDomainKey = "newFireproofDomainKey"
    }

    static let shared = FireproofDomains()

    private let store: FireproofDomainsStore

    @UserDefaultsWrapper(key: .fireproofDomains, defaultValue: nil)
    private var legacyUserDefaultsFireproofDomains: [String]?

    private lazy var fireproofDomainsToIds: [String: NSManagedObjectID] = loadFireproofDomains() {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }
    var fireproofDomains: [String] {
        return Array(fireproofDomainsToIds.keys)
    }

    init(store: FireproofDomainsStore = LocalFireproofDomainsStore()) {
        self.store = store
    }

    private func loadFireproofDomains() -> [String: NSManagedObjectID] {
        do {
            if let fireproofDomains = legacyUserDefaultsFireproofDomains?.map({ $0.dropWWW() }),
                !fireproofDomains.isEmpty,
                let migratedDomains = try? store.add(fireproofDomains: Array(Set(fireproofDomains))) {
                self.legacyUserDefaultsFireproofDomains = nil
                return migratedDomains
            }

            return try store.loadFireproofDomains()
        } catch {
            os_log("FireproofDomainsStore: Failed to load Fireproof Domains", type: .error)
            return [:]
        }
    }

    func toggle(domain: String) -> Bool {
        if isFireproof(fireproofDomain: domain) {
            remove(domain: domain)
            return false
        } else {
            addToAllowed(domain: domain)
            return true
        }
    }

    func addToAllowed(domain: String) {
        guard !isFireproof(fireproofDomain: domain) else {
            return
        }

        let domainWithoutWWW = domain.dropWWW()
        do {
            fireproofDomainsToIds[domainWithoutWWW] = try store.add(fireproofDomain: domainWithoutWWW)
        } catch {
            assertionFailure("could not add fireproof domain \(domain): \(error)")
            return
        }

        NotificationCenter.default.post(name: Constants.newFireproofDomainNotification, object: self, userInfo: [
            Constants.newFireproofDomainKey: domainWithoutWWW
        ])
    }

    public func isFireproof(cookieDomain: String) -> Bool {
        return fireproofDomainsToIds[cookieDomain] != nil
            || fireproofDomainsToIds[cookieDomain.drop(prefix: ".")] != nil
            || (cookieDomain.hasPrefix(".") && fireproofDomainsToIds.contains(where: { key, _ in
                    key.hasSuffix(cookieDomain)
                }))
    }

    func remove(domain: String) {
        let domainWithoutWWW = domain.dropWWW()
        guard let id = fireproofDomainsToIds[domainWithoutWWW] else {
            assertionFailure("fireproof domain \(domain) not found")
            return
        }
        fireproofDomainsToIds[domainWithoutWWW] = nil
        store.remove(objectWithId: id)
    }

    func clearAll() {
        fireproofDomainsToIds = [:]
        store.clear()
    }

    func isFireproof(fireproofDomain domain: String) -> Bool {
        let domainWithoutWWW = domain.dropWWW()
        let dotPrefixedDomain = "." + domainWithoutWWW
        return fireproofDomainsToIds[domainWithoutWWW] != nil
            || fireproofDomainsToIds.contains(where: { key, _ in key.hasSuffix(dotPrefixedDomain) })
    }

    func isURLFireproof(url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        return isFireproof(fireproofDomain: host)
    }

}
