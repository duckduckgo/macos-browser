//
//  ExcludedDomainsModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import NetworkProtectionProxy

protocol AppRulesModel {
    var domains: [String] { get }

    func add(domain: String)
    func remove(domain: String)
}

final class DefaultAppRulesModel {
    let proxySettings = TransparentProxySettings(defaults: .netP)

    init() {
    }
}

extension DefaultAppRulesModel: ExcludedDomainsViewModel {
    var domains: [String] {
        proxySettings.excludedDomains
    }

    func add(domain: String) {
        guard !proxySettings.excludedDomains.contains(domain) else {
            return
        }

        proxySettings.excludedDomains.append(domain)
    }

    func remove(domain: String) {
        proxySettings.excludedDomains.removeAll { cursor in
            domain == cursor
        }
    }
}
