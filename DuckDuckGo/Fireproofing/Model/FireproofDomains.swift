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
    private let store: DataStore

    @UserDefaultsWrapper(key: .fireproofDomains, defaultValue: nil)
    private var legacyUserDefaultsFireproofDomains: [String]?

    private lazy var container: FireproofDomainsContainer = loadFireproofDomains() {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }

    var fireproofDomains: [String] {
        container.domains
    }

    init(store: DataStore = CoreDataStore(tableName: "FireproofDomains")) {
        self.store = store
    }

    private func loadFireproofDomains() -> FireproofDomainsContainer {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            if let domains = legacyUserDefaultsFireproofDomains,
               !domains.isEmpty {

                var container = FireproofDomainsContainer()
                do {
                    let added = try store.add(domains) { (object: FireproofDomainManagedObject, domain) in
                        // filter out duplicate domains
                        guard let domain = try? container.add(domain: domain, withId: object.objectID) else { return }
                        object.update(withDomain: domain)
                    }
                    for (domain, id) in added {
                        container.updateId(id, for: domain)
                    }

                    self.legacyUserDefaultsFireproofDomains = nil
                } catch {}

                return container
            }

            return try store.load(into: FireproofDomainsContainer()) { (container, object: FireproofDomainManagedObject) in
                guard let domain = object.domainEncrypted as? String else { return }
                try container.add(domain: domain, withId: object.objectID)
            }
        } catch {
            os_log("FireproofDomainsStore: Failed to load Fireproof Domains", type: .error)
            return FireproofDomainsContainer()
        }
    }

    func toggle(domain: String) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        if isFireproof(fireproofDomain: domain) {
            remove(domain: domain)
            return false
        }
        addToAllowed(domain: domain)
        return true
    }

    func addToAllowed(domain: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isFireproof(fireproofDomain: domain) else {
            // submodains also?
            return
        }

        let domainWithoutWWW = domain.dropWWW()
        do {
            let id = try store.add(domainWithoutWWW, using: FireproofDomainManagedObject.update)
            try container.add(domain: domainWithoutWWW, withId: id)
        } catch {
            assertionFailure("could not add fireproof domain \(domain): \(error)")
            return
        }

        NotificationCenter.default.post(name: Constants.newFireproofDomainNotification, object: self, userInfo: [
            Constants.newFireproofDomainKey: domainWithoutWWW
        ])
    }

    func remove(domain: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let id = container.remove(domain: domain) else {
            assertionFailure("fireproof domain \(domain) not found")
            return
        }
        store.remove(objectWithId: id)
    }

    func clearAll() {
        dispatchPrecondition(condition: .onQueue(.main))
        container = FireproofDomainsContainer()
        store.clear(objectsOfType: FireproofDomainManagedObject.self)
    }

    func isFireproof(cookieDomain: String) -> Bool {
        let domainWithoutDotPrefix = cookieDomain.drop(prefix: ".")
        return container.contains(domain: domainWithoutDotPrefix, includingSuperdomains: false)
            || (cookieDomain.hasPrefix(".") && container.contains(superdomain: domainWithoutDotPrefix))
    }

    func isFireproof(fireproofDomain domain: String) -> Bool {
        return container.contains(domain: domain)
    }

    func isURLFireproof(url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        return isFireproof(fireproofDomain: host)
    }

}

extension FireproofDomains {
    private struct FireproofDomainsContainer {

        struct DomainAlreadyAdded: Error {}

        private var domainsToIds = [String: NSManagedObjectID]()

        // auto-generated superdomain->subdomain where subdomain is originally fireproofed
        // used for quick search for superdomains when checking in isFireproof(..) functions
        // would store "name.com" -> ["mail.name.com", "news.name.com"]
        // adding "admin.name.com" would add the domain to the related set
        // removing "mail.name.com" would remove the domain from the related set
        // when set goes empty, the record should be removed
        private var superdomainsToSubdomains = [String: Set<String>]()

        var domains: [String] {
            return Array(domainsToIds.keys)
        }

        @discardableResult
        mutating func add(domain: String, withId id: NSManagedObjectID) throws -> String {
            let domain = domain.dropWWW()
            try domainsToIds.updateInPlace(key: domain) { value in
                guard value == nil else { throw DomainAlreadyAdded() }
                value = id
            }
            domainsToIds[domain] = id

            let components = domain.components(separatedBy: ".")
            if components.count > 2 {
                for i in 1..<components.count {
                    let superdomain = components[i..<components.count].joined(separator: ".")
                    superdomainsToSubdomains[superdomain, default: []].insert(domain)
                }
            }

            return domain
        }

        mutating func updateId(_ newID: NSManagedObjectID, for domain: String) {
            domainsToIds.updateInPlace(key: domain.dropWWW()) { id in
                guard id != nil else {
                    assertionFailure("\(domain) not found")
                    return
                }
                id = newID
            }
        }

        mutating func remove(domain: String) -> NSManagedObjectID? {
            let domain = domain.dropWWW()
            guard let idx = domainsToIds.index(forKey: domain) else {
                assertionFailure("\(domain) is not Fireproof")
                return nil
            }
            let id = domainsToIds.remove(at: idx).value

            let components = domain.components(separatedBy: ".")
            guard components.count > 2 else { return id }

            for i in 1..<components.count {
                let superdomain = components[i..<components.count].joined(separator: ".")

                superdomainsToSubdomains.updateInPlace(key: superdomain) { domains in
                    domains?.remove(domain)
                    if domains?.isEmpty == true {
                        domains = nil
                    }
                }
            }

            return id
        }

        func contains(domain: String, includingSuperdomains: Bool = true) -> Bool {
            let domain = domain.dropWWW()
            return domainsToIds[domain] != nil || (includingSuperdomains && contains(superdomain: domain))
        }

        func contains(superdomain: String) -> Bool {
            return superdomainsToSubdomains[superdomain] != nil
        }

    }
}

extension FireproofDomainManagedObject {
    func update(withDomain domain: String) {
        self.domainEncrypted = domain as NSString
    }
}
