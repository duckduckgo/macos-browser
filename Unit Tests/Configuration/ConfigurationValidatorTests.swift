//
//  ConfigurationValidatorTests.swift
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
import TrackerRadarKit
@testable import DuckDuckGo_Privacy_Browser

final class ConfigurationValidatorTests: XCTestCase {

    var validator: ConfigurationValidator!

    override func setUp() {
        super.setUp()
        validator = ConfigurationValidator()
    }

    func testThatValidationNeverFailsForTypesThatAreNotChecked() {
        XCTAssertNoThrow(try validator.validate(Data(), for: .bloomFilterSpec))
        XCTAssertNoThrow(try validator.validate(Data(), for: .bloomFilterBinary))
        XCTAssertNoThrow(try validator.validate(Data(), for: .bloomFilterExcludedDomains))
        XCTAssertNoThrow(try validator.validate(Data(), for: .surrogates))
    }

    func testWhenCorrectTrackerDataIsPassedThenNoErrorIsThrown() throws {
        let tracker = KnownTracker(
            domain: "tracker.com",
            defaultAction: .block,
            owner: .init(name: "Tracker Inc", displayName: "Tracker Inc company"),
            prevalence: 0.1,
            subdomains: nil,
            categories: nil,
            rules: nil
        )

        let trackerData = TrackerData(
            trackers: ["tracker.com": tracker],
            entities: ["Tracker Inc": .init(displayName: "Trackr Inc company", domains: ["tracker.com"], prevalence: 0.1)],
            domains: ["tracker.com": "Tracker Inc"],
            cnames: [:]
        )

        let data = try JSONEncoder().encode(trackerData)

        XCTAssertNoThrow(try validator.validate(data, for: .trackerRadar))
    }

    func testWhenIncorrectTrackerDataIsPassedThenErrorIsThrown() throws {
        let data = try XCTUnwrap(Self.htmlPayload.data(using: .utf8))

        XCTAssertThrowsError(try validator.validate(data, for: .trackerRadar)) { error in
            guard case DefaultConfigurationDownloader.Error.invalidPayload = error else {
                XCTFail("Unexpected error thrown: \(error)")
                return
            }
        }
    }

    func testWhenCorrectPrivacyConfigIsPassedThenNoErrorIsThrown() throws {
        let payload: [String: Any] = [
            "key1": "value",
            "key2": 2,
            "key3": ["a", "b", 0xc]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertNoThrow(try validator.validate(data, for: .privacyConfiguration))
    }

    func testWhenIncorrectPrivacyConfigIsPassedThenErrorIsThrown() throws {
        let data = try XCTUnwrap(Self.htmlPayload.data(using: .utf8))

        XCTAssertThrowsError(try validator.validate(data, for: .privacyConfiguration)) { error in
            guard case DefaultConfigurationDownloader.Error.invalidPayload = error else {
                XCTFail("Unexpected error thrown: \(error)")
                return
            }
        }
    }

    // MARK: - Test data

    private static let htmlPayload = """
        <html>
            <head>
                <title>Hello, World!</title>
            </head>
            <body>
                <p>Hello.</p>
            </body>
        </html>
        """

}
