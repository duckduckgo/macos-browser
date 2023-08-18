//
//  TabUrlExtensionTests.swift
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

final class TabStringExtensionTests: XCTestCase {

    func testSearchWithBangDetection() {
        let searchWithBang: [String] = [
            "https://duckduckgo.com/?q=%21Hello",
            "https://duckduckgo.com/?q=%21Hello%20World",
            "https://duckduckgo.com/?q=%21Search%20With%20Bang"
        ]

        let nonSearchWithBang: [String] = [
            "https://duckduckgo.com/?q=%21",
            "https://duckduckgo.com/?q=%21%20",
            "https://duckduckgo.com/?q=%21%20test",
            "https://duckduckgo.com/?q=test%21test",
        ]

            for url in searchWithBang {
                XCTAssertTrue(url.isSearchWithBang, "\(url) should be detected as a search with bang")
            }

            for url in nonSearchWithBang {
                XCTAssertFalse(url.isSearchWithBang, "\(url) should not be detected as search with bang")
            }
        }
}
