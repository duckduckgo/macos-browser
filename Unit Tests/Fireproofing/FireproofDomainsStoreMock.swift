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

    func loadFireproofDomains() throws -> [String: NSManagedObjectID] {
        history.append(.load)
        if let error = error {
            throw error
        }
        return domains
    }

    func add(fireproofDomain: String) throws -> NSManagedObjectID {
        history.append(.add(domains: [fireproofDomain]))
        if let error = error {
            throw error
        }
        return .init()
    }

    func add(fireproofDomains: [String]) throws -> [String : NSManagedObjectID] {
        history.append(.add(domains: fireproofDomains))
        if let error = error {
            throw error
        }
        return fireproofDomains.reduce(into: [:]) { $0[$1] = .init() }
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)?) {
        history.append(.remove(id))
        completionHandler?(nil)
    }

    func clear(completionHandler: ((Error?) -> Void)?) {
        history.append(.clear)
        completionHandler?(nil)
    }

}
