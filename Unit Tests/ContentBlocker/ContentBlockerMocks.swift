//
//  ContentBlockerMocks.swift
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
import TrackerRadarKit
import BrowserServicesKit

final class MockPrivacyConfiguration: PrivacyConfiguration {

    var identifier = ""

    var userUnprotectedDomains = [String]()

    var tempUnprotectedDomains = [String]()

    var trackerAllowlist = PrivacyConfigurationData.TrackerAllowlistData()

    func isEnabled(featureKey: PrivacyFeature) -> Bool {
        return false
    }

    func exceptionsList(forFeature featureKey: PrivacyFeature) -> [String] {
        return []
    }

    func isFeature(_ feature: PrivacyFeature, enabledForDomain: String?) -> Bool {
        return false
    }

    func isProtected(domain: String?) -> Bool {
        return false
    }

    func isUserUnprotected(domain: String?) -> Bool {
        return false
    }

    func isTempUnprotected(domain: String?) -> Bool {
        return false
    }

    func isInExceptionList(domain: String?, forFeature featureKey: PrivacyFeature) -> Bool {
        return false
    }

    func settings(for feature: PrivacyFeature) -> PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        return [:]
    }

    func userEnabledProtection(forDomain: String) {}

    func userDisabledProtection(forDomain: String) {}

}

final class MockContentBlockerUserScriptConfig: ContentBlockerUserScriptConfig {

    var privacyConfiguration: PrivacyConfiguration = MockPrivacyConfiguration()

    var trackerData: TrackerData?

    var source = ""

}

final class MockSurrogatesUserScriptConfig: SurrogatesUserScriptConfig {

    var privacyConfig: PrivacyConfiguration = MockPrivacyConfiguration()

    var surrogates: String = ""

    var trackerData: TrackerData?

    var encodedSurrogateTrackerData: String?

    var source: String = ""
}
