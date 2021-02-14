//
//  PreserveLogins.swift
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

class FireproofDomains {

    enum Constants {
        static let allowedDomainsChangedNotification = Notification.Name("AllowedDomainsChangedNotification")
        static let newFireproofedDomainNotification = Notification.Name("newFireproofedDomainNotification")
    }

    static let shared = FireproofDomains()

    @UserDefaultsWrapper(key: .preserveLoginsAllowedDomains, defaultValue: [])
    private(set) var allowedDomains: [String] {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }

    func addToAllowed(domain: String) {
        allowedDomains += [domain]

        NotificationCenter.default.post(name: Constants.newFireproofedDomainNotification, object: self, userInfo: [
            "domain": domain
        ])
    }

    func isAllowed(cookieDomain: String) -> Bool {

        return allowedDomains.contains(where: { $0 == cookieDomain
                                        || ".\($0)" == cookieDomain
                                        || (cookieDomain.hasPrefix(".") && $0.hasSuffix(cookieDomain)) })

    }

    func remove(domain: String) {
        allowedDomains = allowedDomains.filter { $0 != domain }
    }

    func clearAll() {
        allowedDomains = []
    }

    func isAllowed(fireproofDomain domain: String) -> Bool {
        return allowedDomains.contains(domain)
    }

}
