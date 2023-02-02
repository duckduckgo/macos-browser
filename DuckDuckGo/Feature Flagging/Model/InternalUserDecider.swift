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
    var isInternalUserPublisher: Published<Bool>.Publisher { get }

    func markUserAsInternalIfNeeded(forUrl url: URL?, response: HTTPURLResponse?)

}

final class InternalUserDecider {

    private static let internalUserVerificationURLHost = "use-login.duckduckgo.com"

    init(store: InternalUserDeciderStoring) {
        self.store = store

#if DEBUG || REVIEW
        if AppDelegate.isRunningTests {
            isInternalUser = (try? store.load()) ?? false
        } else {
            isInternalUser = true
        }
#else
        isInternalUser = (try? store.load()) ?? false
#endif
    }

    private var store: InternalUserDeciderStoring

    @Published private(set) var isInternalUser: Bool {
        didSet {
            // Optimisation below prevents from 2 unnecesary events:
            // 1) Rewriting the file with the same value
            // 2) Also from initial saving of the false value to the disk
            // which is unnecessary since it is the default value.
            // It makes the load of the app faster
            if oldValue != isInternalUser {
                try? store.save(isInternal: isInternalUser)
            }
        }
    }

}

extension InternalUserDecider: InternalUserDeciding {

    var isInternalUserPublisher: Published<Bool>.Publisher {
        $isInternalUser
    }

    func markUserAsInternalIfNeeded(forUrl url: URL?, response: HTTPURLResponse?) {
        if isInternalUser { // If we're already an internal user, we don't need to do anything
            return
        }

        if let url = url,
           url.host == Self.internalUserVerificationURLHost,
           let statusCode = response?.statusCode,
           statusCode == 200 {
            isInternalUser = true
            return
        }

        // Do not publish value if not necessary
        if isInternalUser != false {
            isInternalUser = false
        }
    }

}
