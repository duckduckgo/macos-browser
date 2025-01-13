//
//  AppConfigurationURLProviderTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class AppConfigurationURLProviderTests: XCTestCase {
    private var mockPrivacyConfigurationManager: MockPrivacyConfigurationManager!
    private var mockFeatureFlagger: MockFeatureFlagger!
    private var urlProvider: AppConfigurationURLProvider!

    override func setUp() {
        super.setUp()
        mockPrivacyConfigurationManager = MockPrivacyConfigurationManager()
        mockFeatureFlagger = MockFeatureFlagger()
        urlProvider = AppConfigurationURLProvider(privacyConfigurationManager: mockPrivacyConfigurationManager, featureFlagger: mockFeatureFlagger)
    }

    override func tearDown() {
        urlProvider = nil
        mockPrivacyConfigurationManager = nil
        mockFeatureFlagger = nil
        super.tearDown()
    }

    func testExternalURLDependenciesAreExpected() throws {
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .bloomFilterBinary).absoluteString, "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin")
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .bloomFilterSpec).absoluteString, "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json")
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .bloomFilterExcludedDomains).absoluteString, "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json")
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString, "https://staticcdn.duckduckgo.com/trackerblocking/config/v4/macos-config.json")
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .surrogates).absoluteString, "https://staticcdn.duckduckgo.com/surrogates.txt")
        XCTAssertEqual(AppConfigurationURLProvider().url(for: .trackerDataSet).absoluteString, "https://staticcdn.duckduckgo.com/trackerblocking/v6/current/macos-tds.json")
    }

    func testTrackerDataURL_forControlCohort_returnsControlUrl() {
        // GIVEN
        let featureJson =
        """
            "features": {
                "tdsNextExperimentBaseline": {
                    "state": "enabled",
                    "minSupportedVersion": 52200000,
                    "rollout": {
                        "steps": [
                            {
                                "percent": 50
                            }
                        ]
                    },
                    "settings": {
                        "controlUrl": "control.url.json",
                        "treatmentUrl": "tratement.url.json"
                    },
                    "cohorts": [
                        {
                            "name": "control",
                            "weight": 0
                        },
                        {
                            "name": "treatment",
                            "weight": 1
                        }
                    ]
                },
        """.data(using: .utf8)!
        _ = mockPrivacyConfigurationManager.reload(etag: "2", data: featureJson)

        mockFeatureFlagger.cohort = TdsNextExperimentFlag.Cohort.treatment

        // WHEN
        let url = urlProvider.url(for: .trackerDataSet)

        // THEN
        XCTAssertEqual(url.absoluteString, "tratement.url.json")
    }

}
