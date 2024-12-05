//
//  DuckFaviconURLTests.swift
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

import XCTest
import Combine
@testable import NewTabPage

final class DuckFaviconURLTests: XCTestCase {

    func testDuckFaviconURL() throws {
        XCTAssertEqual(
            URL.duckFavicon(for: URL(string: "https://example.com")!)?.absoluteString,
            "duck://favicon/https%3A//example.com"
        )
        XCTAssertEqual(
            URL.duckFavicon(for: URL(string: "https://example.com/1/2/3#anchor")!)?.absoluteString,
            "duck://favicon/https%3A//example.com/1/2/3%23anchor"
        )
        XCTAssertEqual(
            URL.duckFavicon(for: URL(string: "https://example.com/1/2/3?query=yes&other=no")!)?.absoluteString,
            "duck://favicon/https%3A//example.com/1/2/3%3Fquery=yes&other=no"
        )
        XCTAssertEqual(
            URL.duckFavicon(for: URL(string: "https://рнидс.срб/")!)?.absoluteString,
            "duck://favicon/https%3A//xn--d1aholi.xn--90a3ac/"
        )
    }
}
