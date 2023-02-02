//
//  InternalUserDecider.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

protocol InternalUserDeciding {

    var isInternalUser: Bool { get }

    func markUserAsInternalIfNeeded(forUrl url: URL?, response: HTTPURLResponse?)

}

final class InternalUserDecider {

    private static let internalUserVerificationURLHost = "use-login.duckduckgo.com"

    init(store: InternalUserDeciderStoring) {
        self.store = store

        didVerifyInternalUser = (try? store.load()) ?? false
    }

    private var store: InternalUserDeciderStoring
    private var didVerifyInternalUser: Bool {
        didSet {
            if oldValue != didVerifyInternalUser {
                try? store.save(isInternal: didVerifyInternalUser)
            }
        }
    }

}

extension InternalUserDecider: InternalUserDeciding {

    var isInternalUser: Bool {
//TODO Uncomment
//#if DEBUG
//        return true
//#endif
        return didVerifyInternalUser
    }

    func markUserAsInternalIfNeeded(forUrl url: URL?, response: HTTPURLResponse?) {
        if isInternalUser { // If we're already an internal user, we don't need to do anything
            return
        }

        if let url = url,
           url.host == Self.internalUserVerificationURLHost,
           let statusCode = response?.statusCode,
           statusCode == 200 {
            didVerifyInternalUser = true
            return
        }

        didVerifyInternalUser = false
    }

}
