//
//  BookmarkUrlExtensionTests.swift
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

import Combine
import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser
final class BookmarkUrlExtensionTests: XCTestCase {

    func testWhenUrlIsHttpWithTrailingSlash_ThenCorrectVariantsAreGenerated() {
        let originalURL = URL(string: "http://example.com/")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 4)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "http://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com/")!))
    }

    func testWhenUrlIsHttpsWithoutTrailingSlash_ThenCorrectVariantsAreGenerated() {
        let originalURL = URL(string: "https://example.com")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 4)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "http://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com/")!))
    }

    func testWhenUrlIsHttpWithoutTrailingSlash_ThenCorrectVariantsAreGenerated() {
        let originalURL = URL(string: "http://example.com")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 4)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "https://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com/")!))
    }

    func testWhenUrlIsHttpsWithTrailingSlash_ThenCorrectVariantsAreGenerated() {
        let originalURL = URL(string: "https://example.com/")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 4)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "http://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com")!))
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/")!))
    }

    func testWhenUrlHasNoScheme_ThenNoVariantsGenerated() {
        let originalURL = URL(string: "example.com")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 1)
        XCTAssertEqual(variants[0], originalURL)
    }

    func testWhenUrlHasNonHttpOrHttpsScheme_ThenOnlyOriginalUrlIsReturned() {
        let originalURL = URL(string: "file:///Users/example/file.txt")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 1)
        XCTAssertEqual(variants[0], originalURL)
    }

    func testWhenUrlHasQueryParameters_ThenVariantsAreGeneratedWithoutTrailingSlashes() {
        let originalURL = URL(string: "https://example.com/path/to/resource?query=value")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 2)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/path/to/resource?query=value")!))
    }

    func testWhenUrlHasNoQueryParameters_ThenVariantsIncludeTrailingSlashes() {
        let originalURL = URL(string: "https://example.com/path/to/resource")!

        let variants = originalURL.bookmarkButtonUrlVariants()

        XCTAssertEqual(variants.count, 4)
        XCTAssertEqual(variants[0], originalURL)
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/path/to/resource")!))
        XCTAssertTrue(variants.contains(URL(string: "http://example.com/path/to/resource/")!))
        XCTAssertTrue(variants.contains(URL(string: "https://example.com/path/to/resource/")!))
    }
}
