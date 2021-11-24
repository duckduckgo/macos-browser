//
//  FireproofDomainsStoreMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class FireproofDomainsStoreMock: FireproofDomainsStore {

    final class FakeDataStore: DataStore {
        func clear<ManagedObject>(objectsOfType _: ManagedObject.Type,
                                  completionHandler: ((Error?) -> Void)?) where ManagedObject: NSManagedObject {
            fatalError()
        }

        func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
            fatalError()
        }

        func remove<ManagedObject>(objectsOfType _: ManagedObject.Type,
                                   withPredicate predicate: NSPredicate,
                                   completionHandler: ((Error?) -> Void)?) where ManagedObject: NSManagedObject {
            fatalError()
        }

        func add<Seq, ManagedObject>(_ objects: Seq,
                                     using update: (ManagedObject, Seq.Element) -> Void) throws
            -> [(element: Seq.Element, id: NSManagedObjectID)] where Seq: Sequence, ManagedObject: NSManagedObject {
            fatalError()
        }

        func load<Result, ManagedObject>(into initialResult: Result,
                                         _ update: (inout Result, ManagedObject) throws -> Void) throws
            -> Result where ManagedObject: NSManagedObject {
            fatalError()
        }

        init() {}
    }

    var domains = [String: NSManagedObjectID]()
    var error: Error?

    enum CallHistoryItem: Equatable {
        case load
        case remove(NSManagedObjectID)
        case add(domains: [String])
        case clear
    }

    var history = [CallHistoryItem]()

    init() {
        super.init(store: FakeDataStore()) { fatalError() }
            update: { _, _ in fatalError() }
            combine: { _, _ in fatalError() }

    }

    override func load() throws -> FireproofDomainsContainer {
        history.append(.load)
        if let error = error {
            throw error
        }

        var result = FireproofDomainsContainer()
        for (domain, id) in domains {
            try result.add(domain: domain, withId: id)
        }
        return result
    }

    override func add(_ fireproofDomain: String) throws -> NSManagedObjectID {
        history.append(.add(domains: [fireproofDomain]))
        if let error = error {
            throw error
        }
        domains[fireproofDomain] = .init()
        return domains[fireproofDomain]!
    }

    override func add<Seq: Sequence>(_ fireproofDomains: Seq) throws
        -> [(element: String, id: NSManagedObjectID)] where Seq.Element == String {

        history.append(.add(domains: Array(fireproofDomains)))
        if let error = error {
            throw error
        }
        var result = [(element: String, id: NSManagedObjectID)]()
        for domain in fireproofDomains {
            result.append( (domain, .init()) )
            domains[domain] = result.last!.id
        }
        return result
    }

    override func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)? = nil) {
        history.append(.remove(id))
        domains[domains.first(where: { $0.value == id })!.key] = nil
        completionHandler?(nil)
    }

    override func clear(completionHandler: ((Error?) -> Void)? = nil) {
        history.append(.clear)
        domains = [:]
        completionHandler?(nil)
    }

}
