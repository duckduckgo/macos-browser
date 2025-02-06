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
    case maliciousSiteProtection

    /// Add experimental atb parameter to SERP queries for internal users to display Privacy Reminder
    /// https://app.asana.com/0/1199230911884351/1205979030848528/f
    case appendAtbToSerpQueries

    // https://app.asana.com/0/1206488453854252/1207136666798700/f
    case freemiumDBP

    case contextualOnboarding

    // https://app.asana.com/0/1201462886803403/1208030658792310/f
    case unknownUsernameCategorization

    case credentialsImportPromotionForExistingUsers

    /// https://app.asana.com/0/0/1209150117333883/f
    case networkProtectionAppExclusions

    /// https://app.asana.com/0/72649045549333/1208231259093710/f
    case networkProtectionUserTips

    /// https://app.asana.com/0/72649045549333/1208617860225199/f
    case networkProtectionEnforceRoutes

    /// https://app.asana.com/0/72649045549333/1208241266421040/f
    case htmlNewTabPage

    /// https://app.asana.com/0/1201048563534612/1208850443048685/f
    case historyView

    case autofillPartialFormSaves
    case autcompleteTabs
    case webExtensions
    case syncSeamlessAccountSwitching

    case testExperiment
}

extension FeatureFlag: FeatureFlagDescribing {
    public var cohortType: (any FeatureFlagCohortDescribing.Type)? {
        switch self {
        case .testExperiment:
            return TestExperimentCohort.self
        default:
            return nil
        }
    }

    public enum TestExperimentCohort: String, FeatureFlagCohortDescribing {
        case control
        case treatment
    }

    public var supportsLocalOverriding: Bool {
        switch self {
        case .htmlNewTabPage, .autofillPartialFormSaves, .autcompleteTabs, .networkProtectionAppExclusions, .syncSeamlessAccountSwitching, .historyView, .webExtensions:
            return true
        case .testExperiment:
            return true
        case .debugMenu,
             .sslCertificatesBypass,
             .appendAtbToSerpQueries,
             .freemiumDBP,
             .contextualOnboarding,
             .unknownUsernameCategorization,
             .credentialsImportPromotionForExistingUsers,
             .networkProtectionUserTips,
             .networkProtectionEnforceRoutes,
             .maliciousSiteProtection:
            return false
        }
    }

    public var source: FeatureFlagSource {
        switch self {
        case .debugMenu:
            return .internalOnly()
        case .appendAtbToSerpQueries:
            return .internalOnly()
        case .sslCertificatesBypass:
            return .remoteReleasable(.subfeature(SslCertificatesSubfeature.allowBypass))
        case .unknownUsernameCategorization:
            return .remoteReleasable(.subfeature(AutofillSubfeature.unknownUsernameCategorization))
        case .freemiumDBP:
            return .remoteReleasable(.subfeature(DBPSubfeature.freemium))
        case .maliciousSiteProtection:
            return .remoteReleasable(.subfeature(MaliciousSiteProtectionSubfeature.onByDefault))
        case .contextualOnboarding:
            return .remoteReleasable(.feature(.contextualOnboarding))
        case .credentialsImportPromotionForExistingUsers:
            return .remoteReleasable(.subfeature(AutofillSubfeature.credentialsImportPromotionForExistingUsers))
        case .networkProtectionAppExclusions:
            return .remoteDevelopment(.subfeature(NetworkProtectionSubfeature.appExclusions))
        case .networkProtectionUserTips:
            return .remoteReleasable(.subfeature(NetworkProtectionSubfeature.userTips))
        case .networkProtectionEnforceRoutes:
            return .remoteReleasable(.subfeature(NetworkProtectionSubfeature.enforceRoutes))
        case .htmlNewTabPage:
            return .remoteReleasable(.subfeature(HTMLNewTabPageSubfeature.isLaunched))
        case .historyView:
            return .disabled
        case .autofillPartialFormSaves:
            return .remoteReleasable(.subfeature(AutofillSubfeature.partialFormSaves))
        case .autcompleteTabs:
            return .remoteReleasable(.feature(.autocompleteTabs))
        case .webExtensions:
            return .internalOnly()
        case .syncSeamlessAccountSwitching:
            return .remoteReleasable(.subfeature(SyncSubfeature.seamlessAccountSwitching))
        case .testExperiment:
            return .remoteReleasable(.subfeature(ExperimentTestSubfeatures.experimentTestAA))
        }
    }
}

public extension FeatureFlagger {

    func isFeatureOn(_ featureFlag: FeatureFlag) -> Bool {
        isFeatureOn(for: featureFlag)
    }
}
