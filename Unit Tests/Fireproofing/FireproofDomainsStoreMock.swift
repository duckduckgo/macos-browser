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
        super.init(context: nil, tableName: "")
    }

    override func load<Result>(objectsWithPredicate predicate: NSPredicate? = nil,
                               sortDescriptors: [NSSortDescriptor]? = nil,
                               into initialResult: Result,
                               _ accumulate: (inout Result, IDValueTuple) throws -> Void) throws -> Result {

        history.append(.load)
        if let error = error {
            throw error
        }

        var result = initialResult
        for (domain, id) in domains {
            try accumulate(&result, (id, domain))
        }
        return result
    }

    override func add<S>(_ fireproofDomains: S) throws
        -> [(value: Value, id: NSManagedObjectID)] where S: Sequence, String == S.Element {

        history.append(.add(domains: Array(fireproofDomains)))
        if let error = error {
            throw error
        }
        var result = [(value: String, id: NSManagedObjectID)]()
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
