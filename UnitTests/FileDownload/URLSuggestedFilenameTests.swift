//
//  URLSuggestedFilenameTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class URLSuggestedFilenameTests: XCTestCase {

    func testURLWithFilenameSuggestedFilename() {
        let urlWithFileName = URL(string: "https://www.example.com/file.html")!
        XCTAssertEqual(urlWithFileName.suggestedFilename, "file.html")
    }

    func testURLWithPathSuggestedFilename() {
        let urlWithPath = URL(string: "https://www.example.com/")!
        XCTAssertEqual(urlWithPath.suggestedFilename, "example_com")
    }

    func testURLWithLongerPathSuggestedFilename() {
        let urlWithLongerPath = URL(string: "https://www.example.com/Guitar")!
        XCTAssertEqual(urlWithLongerPath.suggestedFilename, "Guitar")
    }

    func testURLWithLongerPathWithTrailingSlashSuggestedFilename() {
        let urlWithLongerPath = URL(string: "https://www.example.com/Guitar")!
        XCTAssertEqual(urlWithLongerPath.suggestedFilename, "Guitar")
    }

}
