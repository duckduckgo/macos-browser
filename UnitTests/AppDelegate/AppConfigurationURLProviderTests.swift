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
import BrowserServicesKit
import Configuration
@testable import DuckDuckGo_Privacy_Browser

final class AppConfigurationURLProviderTests: XCTestCase {
    private var urlProvider: AppConfigurationURLProvider!
    private var mockTdsURLProvider: MockTrackerDataURLProvider!
    let controlURL = "control/url.json"
    let treatmentURL = "treatment/url.json"

    override func setUp() {
        super.setUp()
        mockTdsURLProvider = MockTrackerDataURLProvider()
        urlProvider = AppConfigurationURLProvider(trackerDataUrlProvider: mockTdsURLProvider)
    }

    override func tearDown() {
        urlProvider = nil
        mockTdsURLProvider = nil
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

    func testUrlForTrackerDataIsDefaultWhenTdsUrlProviderUrlIsNil() {
        // GIVEN
        mockTdsURLProvider.trackerDataURL = nil

        // WHEN
        let url = urlProvider.url(for: .trackerDataSet)

        // THEN
        XCTAssertEqual(url, AppConfigurationURLProvider.Constants.defaultTrackerDataURL)
    }

    func testUrlForTrackerDataIsTheOneProvidedByTdsUrlProvider() {
        // GIVEN
        let expectedURL = URL(string: "https://someurl.com")!
        mockTdsURLProvider.trackerDataURL = expectedURL

        // WHEN
        let url = urlProvider.url(for: .trackerDataSet)

        // THEN
        XCTAssertEqual(url, expectedURL)
    }

}

class MockTrackerDataURLProvider: TrackerDataURLProviding {
    var trackerDataURL: URL?
}
