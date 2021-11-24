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

typealias FireproofDomainsStore = ConcreteDataStore<FireproofDomainManagedObject, FireproofDomainsContainer, String>
final class LocalFireproofDomainsStore: FireproofDomainsStore {

    init(store: DataStore = CoreDataStore(tableName: "FireproofDomains")) {
        super.init(store: store, initContainer: FireproofDomainsContainer.init) { object, domain in
            object.update(withDomain: domain)
        } combine: { container, object in
            guard let domain = object.domainEncrypted as? String else { return }
            try container.add(domain: domain, withId: object.objectID)
        }
    }

}

extension FireproofDomainManagedObject {
    func update(withDomain domain: String) {
        self.domainEncrypted = domain as NSString
    }
}
