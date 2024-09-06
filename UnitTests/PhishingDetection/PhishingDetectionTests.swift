//
//  PhishingDetectionTests.swift
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
import XCTest
import Combine
import PhishingDetection
@testable import DuckDuckGo_Privacy_Browser

final class PhishingDetectionTests: XCTestCase {
    var phishingDetection: PhishingDetection!
    var dataStore: PhishingDetectionDataStore!
    var mockDataActivities: MockPhishingDataActivitites!
    var mockDetector: MockPhishingDetection!
    var mockFileStorageManager: MockFileStorageManager!
    var mockDataProvider: MockDataProvider!

    override func setUp() {
        mockDataActivities = MockPhishingDataActivitites()
        mockDetector = MockPhishingDetection()
        mockFileStorageManager = MockFileStorageManager()
        mockDataProvider = MockDataProvider()
        dataStore = PhishingDetectionDataStore(dataProvider: mockDataProvider, fileStorageManager: mockFileStorageManager)
        phishingDetection = PhishingDetection(dataActivities: mockDataActivities, dataStore: dataStore, detector: mockDetector)
        super.setUp()
    }

    override func tearDown() {
        phishingDetection = nil
        mockDataProvider = nil
        mockFileStorageManager = nil
        mockDataActivities = nil
        mockDetector = nil
        super.tearDown()
    }

    func testDidLoadAndStartDataActivities() async {
        PhishingDetectionPreferences.shared.isEnabled = true
        XCTAssertTrue(mockDataActivities.started)
    }

    func testDisableFeature() async {
        PhishingDetectionPreferences.shared.isEnabled = false
        let isMalicious = await phishingDetection.checkIsMaliciousIfEnabled(url: URL(string: "https://malicious.com")!)
        XCTAssertFalse(isMalicious)
        XCTAssertTrue(mockDataActivities.stopped)
    }

    func testDidNotLoadAndStartDataActivities_IfFeatureDisabled() async {
        PhishingDetectionPreferences.shared.isEnabled = false
        mockDataActivities = MockPhishingDataActivitites()
        mockFileStorageManager = MockFileStorageManager()
        mockDataProvider = MockDataProvider()
        dataStore = PhishingDetectionDataStore(dataProvider: mockDataProvider, fileStorageManager: mockFileStorageManager)
        phishingDetection = PhishingDetection(dataActivities: mockDataActivities, dataStore: dataStore, detector: mockDetector)
        XCTAssertFalse(mockDataProvider.didLoadHashPrefixes)
        XCTAssertFalse(mockDataProvider.didLoadFilterSet)
        XCTAssertFalse(mockDataActivities.started)
        let isMalicious = await phishingDetection.checkIsMaliciousIfEnabled(url: URL(string: "https://malicious.com")!)
        XCTAssertFalse(isMalicious)
        XCTAssertTrue(mockDataActivities.stopped)
    }

    func testIsMalicious() async {
        PhishingDetectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.checkIsMaliciousIfEnabled(url: URL(string: "https://malicious.com")!)
        XCTAssertTrue(isMalicious)
    }

    func testIsNotMalicious() async {
        PhishingDetectionPreferences.shared.isEnabled = true
        let isMalicious = await phishingDetection.checkIsMaliciousIfEnabled(url: URL(string: "https://trusted.com")!)
        XCTAssertFalse(isMalicious)
    }
    
    func testIsMaliciousWithFeatureDisabled() async {
        PhishingDetectionPreferences.shared.isEnabled = false
        let isMalicious = await phishingDetection.checkIsMaliciousIfEnabled(url: URL(string: "https://malicious.com")!)
        XCTAssertFalse(isMalicious)
    }
}
