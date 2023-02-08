//
//  MockPrivacyConfiguration.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import XCTest
import BrowserServicesKit
import Combine
@testable import DuckDuckGo_Privacy_Browser

class MockPrivacyConfiguration: PrivacyConfiguration {
    var identifier: String = "MockPrivacyConfiguration"
    var userUnprotectedDomains: [String] = []
    var tempUnprotectedDomains: [String] = []
    var trackerAllowlist: PrivacyConfigurationData.TrackerAllowlistData = [:]

    func exceptionsList(forFeature featureKey: PrivacyFeature) -> [String] { [] }
    var isFeatureKeyEnabled: ((PrivacyFeature, AppVersionProvider) -> Bool)?
    func isEnabled(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> Bool {
        isFeatureKeyEnabled?(featureKey, versionProvider) ?? true
    }
    func isFeature(_ feature: PrivacyFeature, enabledForDomain: String?) -> Bool { true }
    func isProtected(domain: String?) -> Bool { true }
    func isUserUnprotected(domain: String?) -> Bool { false }
    func isTempUnprotected(domain: String?) -> Bool { false }
    func isInExceptionList(domain: String?, forFeature featureKey: PrivacyFeature) -> Bool { false }
    func settings(for feature: PrivacyFeature) -> PrivacyConfigurationData.PrivacyFeature.FeatureSettings { [:] }
    func userEnabledProtection(forDomain: String) {}
    func userDisabledProtection(forDomain: String) {}
}

@objc(MockPrivacyConfigurationManager)
class MockPrivacyConfigurationManager: NSObject, PrivacyConfigurationManaging {
    var embeddedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData {
        fatalError("not implemented")
    }

    var fetchedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData? {
        fatalError("not implemented")
    }

    var currentConfig: Data {
        Data()
    }

    func reload(etag: String?, data: Data?) -> BrowserServicesKit.PrivacyConfigurationManager.ReloadResult {
        fatalError("not implemented")
    }

    var updatesPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()
    var privacyConfig: PrivacyConfiguration = MockPrivacyConfiguration()
}
