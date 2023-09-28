//
//  DBPMocks.swift
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
import BrowserServicesKit
import Combine

final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {

    var data: Data {
        let configString = """
    {
            "readme": "https://github.com/duckduckgo/privacy-configuration",
            "version": 1693838894358,
            "features": {
                "brokerProtection": {
                    "state": "enabled",
                    "exceptions": [],
                    "settings": {}
                }
            },
            "unprotectedTemporary": []
        }
    """
        let data = configString.data(using: .utf8)
        return data!
    }


    var currentConfig: Data {
        data
    }

    var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

    var privacyConfig: BrowserServicesKit.PrivacyConfiguration {
        let privacyConfigurationData = try! PrivacyConfigurationData(data: data)
        let privacyConfig = privacyConfiguration(withData: privacyConfigurationData)
        return privacyConfig
    }

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        .downloaded
    }
}

func privacyConfiguration(withData data: PrivacyConfigurationData) -> PrivacyConfiguration {
    let domain = MockDomainsProtectionStore()
    return AppPrivacyConfiguration(data: data,
                                   identifier: UUID().uuidString,
                                   localProtection: domain,
                                   internalUserDecider: DefaultInternalUserDecider(store: InternalUserDeciderStoreMock()))
}

final class MockDomainsProtectionStore: DomainsProtectionStore {
    var unprotectedDomains = Set<String>()

    func disableProtection(forDomain domain: String) {
        unprotectedDomains.insert(domain)
    }

    func enableProtection(forDomain domain: String) {
        unprotectedDomains.remove(domain)
    }
}

class InternalUserDeciderStoreMock: InternalUserStoring {
    var isInternalUser: Bool = false
}
