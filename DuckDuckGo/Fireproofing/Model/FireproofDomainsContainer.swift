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

    var domains: [String] {
        return Array(domainsToIds.keys)
    }

    @discardableResult
    mutating func add(domain: String, withId id: NSManagedObjectID) throws -> String {
        try domainsToIds.updateInPlace(key: domain) { value in
            guard value == nil else { throw DomainAlreadyAdded() }
            value = id
        }

        return domain
    }

    mutating func remove(domain: String) -> NSManagedObjectID? {
        guard let idx = domainsToIds.index(forKey: domain) else {
            assertionFailure("\(domain) is not Fireproof")
            return nil
        }
        return domainsToIds.remove(at: idx).value
    }

    func contains(domain: String) -> Bool {
        return domainsToIds[domain] != nil
    }

}
