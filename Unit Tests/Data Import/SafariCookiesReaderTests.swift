//
//  SafariCookiesReaderTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class SafariCookiesReaderTests: XCTestCase {

    func testImportingCookies() {
        let cookiesReader = SafariCookiesReader(safariCookiesFileURL: cookiesFileURL())
        let cookiesResult = cookiesReader.readCookies()

        guard case let .success(cookies) = cookiesResult else {
            XCTFail("Failed to decode cookies")
            return
        }

        XCTAssertEqual(cookies.count, 8)
    }

    private func cookiesFileURL() -> URL {
        let bundle = Bundle(for: FirefoxBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Safari Data/Cookies.binarycookies")
    }
}
