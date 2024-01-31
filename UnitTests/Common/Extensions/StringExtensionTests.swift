//
//  StringExtensionTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class StringExtensionTests: XCTestCase {

    func testHtmlEscapedString() {
        NSError.disableSwizzledDescription = true
        defer { NSError.disableSwizzledDescription = false }

        XCTAssertEqual("\"DuckDuckGo\"®".escapedHtmlString(), "\"DuckDuckGo\"®")
        XCTAssertEqual("i don‘t want to 'sleep'™".escapedHtmlString(), "i don‘t want to 'sleep'™")
        XCTAssertEqual("<some&tag>".escapedHtmlString(), "&lt;some&amp;tag&gt;")
        XCTAssertEqual("© “text” with «emojis» 🩷🦆".escapedHtmlString(), "© “text” with «emojis» 🩷🦆")

        XCTAssertEqual(URLError(URLError.Code.cannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: "Could not connect to the server."]).localizedDescription.escapedHtmlString(), "Could not connect to the server.")
        XCTAssertEqual(URLError(URLError.Code.cannotConnectToHost).localizedDescription.escapedHtmlString(), "The operation couldn’t be completed. (NSURLErrorDomain error -1004.)")
        XCTAssertEqual(URLError(URLError.Code.cannotFindHost).localizedDescription.escapedHtmlString(), "The operation couldn’t be completed. (NSURLErrorDomain error -1003.)")
    }

}
