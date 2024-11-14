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

public enum FeatureFlag: String, CaseIterable {
    case debugMenu
    case sslCertificatesBypass
    case phishingDetectionErrorPage
    case phishingDetectionPreferences

    /// Add experimental atb parameter to SERP queries for internal users to display Privacy Reminder
    /// https://app.asana.com/0/1199230911884351/1205979030848528/f
    case appendAtbToSerpQueries

    // https://app.asana.com/0/1206488453854252/1207136666798700/f
    case freemiumDBP

    case contextualOnboarding

    // https://app.asana.com/0/1201462886803403/1208030658792310/f
    case unknownUsernameCategorization

    case credentialsImportPromotionForExistingUsers

    /// https://app.asana.com/0/72649045549333/1208231259093710/f
    case networkProtectionUserTips

    /// https://app.asana.com/0/72649045549333/1208617860225199/f
    case networkProtectionEnforceRoutes

    /// https://app.asana.com/0/72649045549333/1208241266421040/f
    case htmlNewTabPage
}

extension FeatureFlag: FeatureFlagDescribing {
    public var supportsLocalOverriding: Bool {
        switch self {
        case .htmlNewTabPage:
            return true
        default:
            return false
        }
    }

    public var source: FeatureFlagSource {
        switch self {
        case .debugMenu:
            return .internalOnly
        case .appendAtbToSerpQueries:
            return .internalOnly
        case .sslCertificatesBypass:
            return .remoteReleasable(.subfeature(SslCertificatesSubfeature.allowBypass))
        case .unknownUsernameCategorization:
            return .remoteReleasable(.subfeature(AutofillSubfeature.unknownUsernameCategorization))
        case .freemiumDBP:
            return .remoteReleasable(.subfeature(DBPSubfeature.freemium))
        case .phishingDetectionErrorPage:
            return .remoteReleasable(.subfeature(PhishingDetectionSubfeature.allowErrorPage))
        case .phishingDetectionPreferences:
            return .remoteReleasable(.subfeature(PhishingDetectionSubfeature.allowPreferencesToggle))
        case .contextualOnboarding:
            return .remoteReleasable(.feature(.contextualOnboarding))
        case .credentialsImportPromotionForExistingUsers:
            return .remoteReleasable(.subfeature(AutofillSubfeature.credentialsImportPromotionForExistingUsers))
        case .networkProtectionUserTips:
            return .remoteDevelopment(.subfeature(NetworkProtectionSubfeature.userTips))
        case .networkProtectionEnforceRoutes:
            return .remoteDevelopment(.subfeature(NetworkProtectionSubfeature.enforceRoutes))
        case .htmlNewTabPage:
            return .disabled
        }
    }
}

public extension FeatureFlagger {

    func isFeatureOn(_ featureFlag: FeatureFlag) -> Bool {
        isFeatureOn(for: featureFlag)
    }
}
