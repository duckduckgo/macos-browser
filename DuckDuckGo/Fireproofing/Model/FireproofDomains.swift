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

import Common
import Foundation
import CoreData
import os.log

internal class FireproofDomains {

    enum Constants {
        static let allowedDomainsChangedNotification = Notification.Name("allowedDomainsChangedNotification")
        static let newFireproofDomainNotification = Notification.Name("newFireproofedDomainNotification")
        static let newFireproofDomainKey = "newFireproofDomainKey"
    }

    static let shared = FireproofDomains(tld: ContentBlocking.shared.tld)
    private let store: FireproofDomainsStore

    let tld: TLD

    @UserDefaultsWrapper(key: .fireproofDomains, defaultValue: nil)
    private var legacyUserDefaultsFireproofDomains: [String]?

    @UserDefaultsWrapper(key: .areDomainsMigratedToETLDPlus1, defaultValue: false)
    private var areDomainsMigratedToETLDPlus1: Bool

    private lazy var container: FireproofDomainsContainer = loadFireproofDomains() {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }

    var fireproofDomains: [String] {
        container.domains
    }

    init(store: FireproofDomainsStore = FireproofDomainsStore(tableName: "FireproofDomains"), tld: TLD = ContentBlocking.shared.tld) {
        self.store = store
        self.tld = tld

        migrateFireproofDomainsToETLDPlus1()
    }

    private func loadFireproofDomains() -> FireproofDomainsContainer {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            if let domains = legacyUserDefaultsFireproofDomains,
               !domains.isEmpty {

                var container = FireproofDomainsContainer()
                do {
                    let eTLDPlus1Domains = Set(domains).convertedToETLDPlus1(tld: tld)
                    let added = try store.add(eTLDPlus1Domains)
                    for (domain, id) in added {
                        try container.add(domain: domain, withId: id)
                    }

                    self.legacyUserDefaultsFireproofDomains = nil
                } catch {}

                return container
            }

            return try store.load()
        } catch {
            Logger.fire.error("FireproofDomainsStore: Failed to load Fireproof Domains")
            return FireproofDomainsContainer()
        }
    }

    private func migrateFireproofDomainsToETLDPlus1() {
        // Perform migration to eTLD+1
        if !areDomainsMigratedToETLDPlus1 {
            for domain in container.domains {
                if let eTLDPlus1Domain = tld.eTLDplus1(domain),
                   domain != eTLDPlus1Domain {
                    remove(domain: domain, changeToETLDPlus1: false)
                    add(domain: eTLDPlus1Domain, notify: false)
                }
            }
            areDomainsMigratedToETLDPlus1 = true
        }
    }

    func toggle(domain: String) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        if isFireproof(fireproofDomain: domain) {
            remove(domain: domain)
            return false
        }
        add(domain: domain)
        return true
    }

    func add(domain: String, notify: Bool = true) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let eTLDPlus1Domain = tld.eTLDplus1(domain) else {
            // eTLD+1 domain not available, domain is probably invalid
            return
        }
        guard !isFireproof(fireproofDomain: eTLDPlus1Domain) else {
            return
        }

        do {
            let id = try store.add(eTLDPlus1Domain)
            try container.add(domain: eTLDPlus1Domain, withId: id)
        } catch {
            assertionFailure("could not add fireproof domain \(eTLDPlus1Domain): \(error)")
            return
        }

        if notify {
            NotificationCenter.default.post(name: Constants.newFireproofDomainNotification, object: self, userInfo: [
                Constants.newFireproofDomainKey: eTLDPlus1Domain
            ])
        }
    }

    func remove(domain: String, changeToETLDPlus1: Bool = true) {
        dispatchPrecondition(condition: .onQueue(.main))

        let newDomain: String
        if changeToETLDPlus1 {
            guard let eTLDPlus1Domain = tld.eTLDplus1(domain) else {
                // eTLD+1 domain not available, domain is probably invalid
                return
            }

            newDomain = eTLDPlus1Domain
        } else {
            newDomain = domain
        }

        guard let id = container.remove(domain: newDomain) else {
            assertionFailure("fireproof domain \(newDomain) not found")
            return
        }

        store.remove(objectWithId: id) { error in
            if let error = error {
                assertionFailure("FireproofDomainsStore: Failed to remove Fireproof Domain: \(error)")
                return
            }
        }
    }

    func clearAll() {
        dispatchPrecondition(condition: .onQueue(.main))
        container = FireproofDomainsContainer()
        store.clear()
    }

    func isFireproof(cookieDomain: String) -> Bool {
        let domainWithoutDotPrefix = cookieDomain.dropping(prefix: ".")
        guard let eTLDPlus1Domain = tld.eTLDplus1(domainWithoutDotPrefix) else {
            // eTLD+1 domain not available, domain is probably invalid
            return false
        }

        return container.contains(domain: eTLDPlus1Domain)
    }

    func isFireproof(fireproofDomain domain: String) -> Bool {
        guard let eTLDPlus1Domain = tld.eTLDplus1(domain) else {
            // eTLD+1 domain not available, domain is probably invalid
            return false
        }
        return container.contains(domain: eTLDPlus1Domain)
    }

    func isURLFireproof(url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        return isFireproof(fireproofDomain: host)
    }

}
