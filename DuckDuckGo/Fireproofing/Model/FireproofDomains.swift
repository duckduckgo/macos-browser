//
//  FireproofDomains.swift
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

internal class FireproofDomains {

    enum Constants {
        static let allowedDomainsChangedNotification = Notification.Name("allowedDomainsChangedNotification")
        static let newFireproofDomainNotification = Notification.Name("newFireproofedDomainNotification")
        static let newFireproofDomainKey = "newFireproofDomainKey"
    }

    static let shared = FireproofDomains()

    @UserDefaultsWrapper(key: .fireproofDomains, defaultValue: [])
    private(set) var fireproofDomains: [String] {
        didSet {
            NotificationCenter.default.post(name: Constants.allowedDomainsChangedNotification, object: self)
        }
    }

    func toggle(domain: String) -> Bool {
        if isFireproof(fireproofDomain: domain) {
            remove(domain: domain)
            return false
        } else {
            addToAllowed(domain: domain)
            return true
        }
    }

    func addToAllowed(domain: String) {
        guard !isFireproof(fireproofDomain: domain) else {
            return
        }

        fireproofDomains += [domain]

        NotificationCenter.default.post(name: Constants.newFireproofDomainNotification, object: self, userInfo: [
            Constants.newFireproofDomainKey: domain
        ])
    }

    public func isFireproof(cookieDomain: String) -> Bool {
        fireproofDomains.contains {
            $0 == cookieDomain
                || ".\($0)" == cookieDomain
                || (cookieDomain.hasPrefix(".") && $0.hasSuffix(cookieDomain))
        }
    }

    func remove(domain: String) {
        fireproofDomains.removeAll {
            $0 == domain || $0 == "www.\(domain)"
        }
    }

    func clearAll() {
        fireproofDomains = []
    }

    func isFireproof(fireproofDomain domain: String) -> Bool {
        return fireproofDomains.contains(where: { $0.hasSuffix(domain) || $0.dropWWW().hasSuffix(domain) })
    }

    func isURLFireproof(url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        return isFireproof(fireproofDomain: host)
    }

}
