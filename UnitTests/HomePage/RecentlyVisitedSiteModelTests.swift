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

    @MainActor
    private func RecentlyVisitedSiteModel(originalURL: URL, duckPlayer: DuckPlayerMode = .disabled) -> HomePage.Models.RecentlyVisitedSiteModel? {
        HomePage.Models.RecentlyVisitedSiteModel(originalURL: originalURL, bookmarkManager: LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(), faviconManagement: FaviconManagerMock()), fireproofDomains: FireproofDomains(store: FireproofDomainsStoreMock()), duckPlayer: .mock(withMode: duckPlayer))
    }

    @MainActor
    func testWhenOriginalURLIsHTTPS_ThenModelURLIsHTTPS() {
        assertModelWithURL(URL(string: "https://example.com")!, matches: URL(string: "https://example.com")!, expectedDomain: "example.com")
    }

    @MainActor
    func testWhenOriginalURLIsHTTP_ThenModelURLIsHTTP() {
        assertModelWithURL(URL(string: "http://example.com")!, matches: URL(string: "http://example.com")!, expectedDomain: "example.com")
    }

    @MainActor
    func testWhenOriginalURLContainsAdditionalInformation_ThenModelURLOnlyUsesSchemeAndHost() {
        assertModelWithURL(URL(string: "http://example.com/path?test=true#fragment")!, matches: URL(string: "http://example.com")!, expectedDomain: "example.com")
        assertModelWithURL(URL(string: "https://example.com/path?test=true#fragment")!, matches: URL(string: "https://example.com")!, expectedDomain: "example.com")
    }

    @MainActor
    func testWhenOriginalURLContainsWWW_ThenDomainDoesNotIncludeIt() {
        assertModelWithURL(URL(string: "http://www.example.com")!, matches: URL(string: "http://www.example.com")!, expectedDomain: "example.com")
    }

    @MainActor
    func testWhenDuckPlayerIsEnabled_ThenDuckPlayerURLSetsDomainPlaceholder() {
        let model = RecentlyVisitedSiteModel(originalURL: .effectiveDuckPlayer("abcde12345"), duckPlayer: .enabled)
        XCTAssertEqual(model?.isRealDomain, false)
        XCTAssertEqual(model?.domainToDisplay, DuckPlayer.commonName)
    }

    @MainActor
    func testWhenDuckPlayerIsDisabled_ThenDuckPlayerURLDoesNotSetDomainPlaceholder() {
        let url = URL.effectiveDuckPlayer("abcde12345")
        let model = RecentlyVisitedSiteModel(originalURL: url)
        XCTAssertEqual(model?.isRealDomain, true)
        XCTAssertEqual(model?.domainToDisplay, model?.domain)
    }

    @MainActor
    private func assertModelWithURL(_ url: URL, matches expectedURL: URL, expectedDomain: String) {
        let model = RecentlyVisitedSiteModel(originalURL: url)
        XCTAssertEqual(model?.isRealDomain, true)
        XCTAssertEqual(model?.domain, expectedDomain)
        XCTAssertEqual(model?.url, expectedURL)
    }
}
