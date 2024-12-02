//
//  ReleaseNotesParserTests.swift
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
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class ReleaseNotesParserTests: XCTestCase {

    final class ReleaseNotesParserTests: XCTestCase {

        func testParseReleaseNotes_withEmptyDescription() {
            let description: String? = nil
            let (standard, privacyPro) = ReleaseNotesParser.parseReleaseNotes(from: description)

            XCTAssertTrue(standard.isEmpty)
            XCTAssertTrue(privacyPro.isEmpty)
        }

        func testParseReleaseNotes_withOnlyStandardNotes() {
            let description = """
            <h3>What's new</h3>
            <ul>
                <li>New feature A</li>
                <li>Improvement B</li>
            </ul>
            """
            let (standard, privacyPro) = ReleaseNotesParser.parseReleaseNotes(from: description)

            XCTAssertEqual(standard, ["New feature A", "Improvement B"])
            XCTAssertTrue(privacyPro.isEmpty)
        }

        func testParseReleaseNotes_withOnlyPrivacyProNotes() {
            let description = """
            <h3>For Privacy Pro subscribers</h3>
            <ul>
                <li>Exclusive feature X</li>
                <li>Exclusive improvement Y</li>
            </ul>
            """
            let (standard, privacyPro) = ReleaseNotesParser.parseReleaseNotes(from: description)

            XCTAssertTrue(standard.isEmpty)
            XCTAssertEqual(privacyPro, ["Exclusive feature X", "Exclusive improvement Y"])
        }

        func testParseReleaseNotes_withBothSections() {
            let description = """
            <h3>What's new</h3>
            <ul>
                <li>New feature A</li>
                <li>Improvement B</li>
            </ul>
            <h3>For Privacy Pro subscribers</h3>
            <ul>
                <li>Exclusive feature X</li>
                <li>Exclusive improvement Y</li>
            </ul>
            """
            let (standard, privacyPro) = ReleaseNotesParser.parseReleaseNotes(from: description)

            XCTAssertEqual(standard, ["New feature A", "Improvement B"])
            XCTAssertEqual(privacyPro, ["Exclusive feature X", "Exclusive improvement Y"])
        }

        func testParseReleaseNotes_withInvalidHTML() {
            let description = """
            <h3>What's new</h3>
            <ul>
                <li>New feature A</li>
                <li>Improvement B
            </ul>
            <h3>For Privacy Pro subscribers</h3>
            <ul>
                <li>Exclusive feature X</li>
                <li>Exclusive improvement Y</li>
            </ul>
            """
            let (standard, privacyPro) = ReleaseNotesParser.parseReleaseNotes(from: description)

            XCTAssertEqual(standard, ["New feature A"])
            XCTAssertEqual(privacyPro, ["Exclusive feature X", "Exclusive improvement Y"])
        }

    }

}
