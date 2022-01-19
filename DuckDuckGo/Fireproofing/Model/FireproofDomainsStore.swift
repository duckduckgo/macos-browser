//
//  FireproofDomainsStore.swift
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

typealias FireproofDomainsStore = CoreDataStore<FireproofDomainManagedObject>
extension FireproofDomainsStore {

    func load() throws -> FireproofDomainsContainer {
        try load(into: FireproofDomainsContainer()) {
            try $0.add(domain: $1.value, withId: $1.id)
        }
    }

}

extension FireproofDomainManagedObject: ValueRepresentableManagedObject {

    func update(with domain: String) {
        self.domainEncrypted = domain as NSString
    }

    func valueRepresentation() -> String? {
        self.domainEncrypted as? String
    }

}
