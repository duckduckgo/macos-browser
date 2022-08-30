//
//  RecentlyVisitedSiteModelTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class RecentlyVisitedSiteModelTests: XCTestCase {

    func testWhenOriginalURLIsHTTPS_ThenModelURLIsHTTPS() {
        assertModelWithURL(URL(string: "https://example.com")!, matches: URL(string: "https://example.com")!)
    }
    
    func testWhenOriginalURLIsHTTP_ThenModelURLIsHTTP() {
        assertModelWithURL(URL(string: "http://example.com")!, matches: URL(string: "http://example.com")!)
    }
    
    func testWhenOriginalURLContainsAdditionalInformation_ThenModelURLOnlyUsesSchemeAndHost() {
        assertModelWithURL(URL(string: "http://example.com/path?test=true#fragment")!, matches: URL(string: "http://example.com")!)
        assertModelWithURL(URL(string: "https://example.com/path?test=true#fragment")!, matches: URL(string: "https://example.com")!)
    }
    
    func testWhenUsingDataURL_ThenOnlySchemeIsReturned() {
        assertModelWithURL(URL(string: "data:text/html,%3Ch1%3EHello%2C%20World%21%3C%2Fh1%3E")!, matches: URL(string: "data:")!)
    }
    
    private func assertModelWithURL(_ url: URL, matches expectedURL: URL) {
        let model = HomePage.Models.RecentlyVisitedSiteModel(domain: "example.com", originalURL: url)
        XCTAssertEqual(model.url, expectedURL)
    }

}
