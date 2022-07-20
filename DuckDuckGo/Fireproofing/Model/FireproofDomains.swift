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

    private lazy var container: FireproofDomainsContainer = loadFireproofDomains() {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }

    var fireproofDomains: [String] {
        container.domains
    }

    init(store: FireproofDomainsStore = FireproofDomainsStore(tableName: "FireproofDomains")) {
        self.store = store
    }

    private func loadFireproofDomains() -> FireproofDomainsContainer {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            if let domains = legacyUserDefaultsFireproofDomains?.map({ $0.dropWWW() }),
               !domains.isEmpty {

                var container = FireproofDomainsContainer()
                do {
                    let added = try store.add(Set(domains))
                    for (domain, id) in added {
                        try container.add(domain: domain, withId: id)
                    }

                    self.legacyUserDefaultsFireproofDomains = nil
                } catch {}

                return container
            }

            return try store.load()
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
        add(domain: domain)
        return true
    }

    func add(domain: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isFireproof(fireproofDomain: domain) else {
            // submodains also?
            return
        }

        let domainWithoutWWW = domain.dropWWW()
        do {
            let id = try store.add(domainWithoutWWW)
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

    enum FireproofStatus {
        case noFireproofedDomain
        case containsFireproofedDomain
        case allDomainsAreFireproofed
    }

    func getFireproofedStatus(for visits: [Visit]) -> FireproofStatus {
        guard visits.count > 0 else {
            return .noFireproofedDomain
        }

        let fireproofedVisits = visits.filter { visit in
            if let domain = visit.historyEntry?.url.host, isFireproof(fireproofDomain: domain) {
                return true
            }

            return false
        }

        switch fireproofedVisits.count {
        case 0: return .noFireproofedDomain
        case visits.count: return .allDomainsAreFireproofed
        default: return .containsFireproofedDomain
        }
    }
}
