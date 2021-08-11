//
//  PrivacyConfigurationManagerTests.swift
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

import XCTest
import CommonCrypto
import TrackerRadarKit
@testable import DuckDuckGo_Privacy_Browser

class PrivacyConfigurationManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: DefaultConfigurationStorage.shared.fileUrl(for: .privacyConfiguration))
    }

    func testWhenReloadCalledInitiallyThenConfigurationIsEmbedded() {
        XCTAssertEqual(PrivacyConfigurationManager.shared.reload(), .embedded)
    }
    
    func testConfigurationFeaturesEnabled() {
        PrivacyConfigurationManager.shared.reload()
        XCTAssertTrue(PrivacyConfigurationManager.shared.config.isEnabled(featureKey: .contentBlocking))
    }
    
    func testEmbeddedParsingDoesntCrash() {
        let data = PrivacyConfigurationManager.loadEmbeddedAsData()
        XCTAssertNotNil(try? JSONDecoder().decode(PrivacyConfiguration.self, from: data))
    }

}
