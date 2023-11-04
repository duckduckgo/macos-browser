//
//  DataBrokerProtectionFeatureVisibility.swift
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

protocol DataBrokerProtectionFeatureVisibility {
    func isFeatureVisible() -> Bool
}

struct DefaultDataBrokerProtectionFeatureVisibility: DataBrokerProtectionFeatureVisibility {
    private let privacyConfigurationManager: PrivacyConfigurationManaging

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    func isFeatureVisible() -> Bool {
        isMinimumSystemVersionMet && isUserLocaleAllowed && isFeatureEnabled
    }

    private var isMinimumSystemVersionMet: Bool {
        if #available(macOS 11.4, *) {
            return true
        }
        return false
    }

    private var isUserLocaleAllowed: Bool {
        var regionCode: String?
        if #available(macOS 13, *) {
            regionCode = Locale.current.region?.identifier
        } else {
            regionCode = Locale.current.regionCode
        }

        #if DEBUG // Always assume US for debug builds
        regionCode = "US"
        #endif

        return (regionCode ?? "US") == "US"
    }

    private var isFeatureEnabled: Bool {
        // We should check for the feature flag
        return true
    }
}
