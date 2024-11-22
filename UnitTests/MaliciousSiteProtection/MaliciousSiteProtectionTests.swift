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
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class MaliciousSiteProtectionTests: XCTestCase {
    var phishingDetection: MaliciousSiteDetecting!
    var mockDataActivities: MockPhishingDataActivitites!
    var mockDetector: MockMaliciousSiteDetector!
    var mockDataProvider: MockMaliciousSiteDataProvider!

    override func setUp() {
        mockDataActivities = MockPhishingDataActivitites()
        let mockFileStore = MockMaliciousSiteFileStore()
        mockDataProvider = MockMaliciousSiteDataProvider()

        let dataManager = MaliciousSiteProtection.DataManager(embeddedDataProvider: mockDataProvider, fileStore: mockFileStore)
        phishingDetection = MaliciousSiteProtectionManager(dataManager: dataManager, detector: MockMaliciousSiteDetector(), dataActivities: mockDataActivities, featureFlagger: MockFeatureFlagger())
        super.setUp()
    }

    override func tearDown() {
        phishingDetection = nil
        mockDataProvider = nil
        mockDataActivities = nil
        mockDetector = nil
        super.tearDown()
    }

    func testDidLoadAndStartDataActivities() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        XCTAssertTrue(mockDataActivities.started)
    }

    func testDisableFeature() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://malicious.com")!)
        XCTAssertNil(isMalicious)
    }

    func testDidNotLoadAndStartDataActivities_IfFeatureDisabled() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        XCTAssertFalse(mockDataProvider.didLoadHashPrefixes)
        XCTAssertFalse(mockDataProvider.didLoadFilterSet)
        XCTAssertFalse(mockDataActivities.started)
        XCTAssertTrue(mockDataActivities.stopped)
    }

    func testIsMalicious() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://malicious.com")!)
        XCTAssertEqual(isMalicious, .phishing)
    }

    func testIsNotMalicious() async {
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.evaluate(URL(string: "https://trusted.com")!)
        XCTAssertNil(isMalicious)
    }
}

extension MaliciousSiteProtectionTests {
    class MockFeatureFlagger: FeatureFlagger {
        var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
        var localOverrides: FeatureFlagLocalOverriding?

        func isFeatureOn<Flag: FeatureFlagDescribing>(for featureFlag: Flag, allowOverride: Bool) -> Bool {
            return true
        }

    }
}
