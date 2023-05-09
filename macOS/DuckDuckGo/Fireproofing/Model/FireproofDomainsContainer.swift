//
//  FireproofDomainsContainer.swift
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

struct FireproofDomainsContainer {

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
        let domain = domain.droppingWwwPrefix()
        try domainsToIds.updateInPlace(key: domain) { value in
            guard value == nil else { throw DomainAlreadyAdded() }
            value = id
        }

        let components = domain.components(separatedBy: ".")
        if components.count > 2 {
            for i in 1..<components.count {
                let superdomain = components[i..<components.count].joined(separator: ".")
                superdomainsToSubdomains[superdomain, default: []].insert(domain)
            }
        }

        return domain
    }

    mutating func remove(domain: String) -> NSManagedObjectID? {
        let domain = domain.droppingWwwPrefix()
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
        let domain = domain.droppingWwwPrefix()
        return domainsToIds[domain] != nil || (includingSuperdomains && contains(superdomain: domain))
    }

    func contains(superdomain: String) -> Bool {
        return superdomainsToSubdomains[superdomain] != nil
    }

}
