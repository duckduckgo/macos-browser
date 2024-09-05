//
//  WebsiteInfoTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class WebsiteInfoTests: XCTestCase {

    // MARK: - URL

    @MainActor
    func testWhenInitWithTabThenSetURLWithTabURLValue() throws {
        // GIVEN
        let url = URL.duckDuckGo
        let websiteInfo = try XCTUnwrap(WebsiteInfo.makeWebsitesInfo(url: url).first)

        // WHEN
        let result = websiteInfo.url

        // THEN
        XCTAssertEqual(result, url)
    }

    // MARK: - Title

    @MainActor
    func testWhenTitleIsNotNilThenDisplayTitleReturnsTitleValue() throws {
        // GIVEN
        let title = #function
        let websiteInfo = try XCTUnwrap(WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, title: title).first)

        // WHEN
        let result = websiteInfo.title

        // THEN
        XCTAssertEqual(result, title)
    }

    @MainActor
    func testWhenTitleIsNilAndURLConformsToRFC3986ThenDisplayTitleReturnsURLHost() throws {
        // GIVEN
        let url = URL.duckDuckGo
        let websiteInfo = try XCTUnwrap(WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, title: nil).first)

        // WHEN
        let result = websiteInfo.title

        // THEN
        XCTAssertEqual(result, url.host)
    }

    @MainActor
    func testWhenTitleIsNilAndURLDoesNotConformToRFC3986ThenDisplayTitleReturnsURLAbsoluteString() throws {
        // GIVEN
        let invalidURL = try XCTUnwrap(URL(string: "duckduckgo.com"))
        let websiteInfo = try XCTUnwrap(WebsiteInfo.makeWebsitesInfo(url: invalidURL, title: nil).first)

        // WHEN
        let result = websiteInfo.title

        // THEN
        XCTAssertEqual(result, invalidURL.absoluteString)
    }

}
