//
//  FeatureFlag.swift
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

public enum FeatureFlag: String {
    case debugMenu
    case sslCertificatesBypass

    /// Add experimental atb parameter to SERP queries for internal users to display Privacy Reminder
    /// https://app.asana.com/0/1199230911884351/1205979030848528/f
    case appendAtbToSerpQueries

    // https://app.asana.com/0/72649045549333/1207597760316574/f
    case deduplicateLoginsOnImport

    // https://app.asana.com/0/1206488453854252/1207136666798700/f
    case freemiumPIR
}

extension FeatureFlag: FeatureFlagSourceProviding {
    public var source: FeatureFlagSource {
        switch self {
        case .debugMenu:
            return .internalOnly
        case .appendAtbToSerpQueries:
            return .internalOnly
        case .sslCertificatesBypass:
            return .remoteReleasable(.subfeature(sslCertificatesSubfeature.allowBypass))
        case .deduplicateLoginsOnImport:
            return .remoteReleasable(.subfeature(AutofillSubfeature.deduplicateLoginsOnImport))
        case .freemiumPIR:
            return .remoteDevelopment(.subfeature(DBPSubfeature.freemium))
        }
    }
}

extension FeatureFlagger {
    public func isFeatureOn(_ featureFlag: FeatureFlag) -> Bool {
        isFeatureOn(forProvider: featureFlag)
    }
}
