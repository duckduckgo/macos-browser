//
//  MaliciousSiteProtectionTests.swift
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

import BrowserServicesKit
import Combine
import Foundation
import MaliciousSiteProtection
import PersistenceTestingUtils
import NetworkingTestingUtils
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class MaliciousSiteProtectionTests: XCTestCase {
    lazy var phishingDetection: MaliciousSiteProtectionManager! = { () -> MaliciousSiteProtectionManager in
        let configManager = MockPrivacyConfigurationManager()
        let privacyConfig = MockPrivacyConfiguration()
        privacyConfig.isSubfeatureKeyEnabled = { (subfeature: any PrivacySubfeature, _: AppVersionProvider) -> Bool in
            if case MaliciousSiteProtectionSubfeature.onByDefault = subfeature { true } else { false }
        }
        configManager.privacyConfig = privacyConfig
        return MaliciousSiteProtectionManager(apiService: apiService, dataManager: dataManager, detector: MockMaliciousSiteDetector(), featureFlags: MaliciousSiteProtectionFeatureFlags(privacyConfigManager: configManager, isMaliciousSiteProtectionEnabled: { true }))
    }()
    var apiService: MockAPIService!
    var mockDetector: MockMaliciousSiteDetector!
    var mockDataProvider: MockMaliciousSiteDataProvider!
    var dataManager: MaliciousSiteProtection.DataManager!

    override func setUp() async throws {
        apiService = MockAPIService(apiResponse: .failure(CancellationError()))
        let mockFileStore = MockMaliciousSiteFileStore()
        mockDataProvider = MockMaliciousSiteDataProvider()
        dataManager = MaliciousSiteProtection.DataManager(fileStore: mockFileStore, embeddedDataProvider: mockDataProvider, fileNameProvider: { _ in "file.json" })
    }

    override func tearDown() async throws {
        phishingDetection = nil
        mockDataProvider = nil
        mockDetector = nil
        dataManager = nil
    }

    func testDidLoadAndStartDataActivities() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        XCTAssertTrue(phishingDetection.backgroundUpdatesEnabled)
    }

    func testWhenFeatureDisabled_phishingIsNotDetected() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://phishing.com")!)
        XCTAssertNil(isMalicious)
    }
    func testWhenFeatureDisabled_malwareIsNotDetected() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://malware.com")!)
        XCTAssertNil(isMalicious)
    }

    func testDidNotLoadAndStartDataActivities_IfFeatureDisabled() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        _=phishingDetection
        for _ in 0..<100 { await Task.yield() }
        XCTAssertFalse(mockDataProvider.didLoadHashPrefixes)
        XCTAssertFalse(mockDataProvider.didLoadFilterSet)
        XCTAssertFalse(phishingDetection.backgroundUpdatesEnabled)
    }

    func testWhenPhishingDetected_phishingThreatReturned() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://phishing.com")!)
        XCTAssertEqual(isMalicious, .phishing)
    }

    func testWhenMalwareDetected_malwareThreatReturned() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://malware.com")!)
        XCTAssertEqual(isMalicious, .malware)
    }

    func testIsNotMalicious() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://trusted.com")!)
        XCTAssertNil(isMalicious)
    }
}
