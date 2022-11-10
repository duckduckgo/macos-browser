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
        assertModelWithURL(URL(string: "https://example.com")!, matches: URL(string: "https://example.com")!, expectedDomain: "example.com")
    }
    
    func testWhenOriginalURLIsHTTP_ThenModelURLIsHTTP() {
        assertModelWithURL(URL(string: "http://example.com")!, matches: URL(string: "http://example.com")!, expectedDomain: "example.com")
    }
    
    func testWhenOriginalURLContainsAdditionalInformation_ThenModelURLOnlyUsesSchemeAndHost() {
        assertModelWithURL(URL(string: "http://example.com/path?test=true#fragment")!, matches: URL(string: "http://example.com")!, expectedDomain: "example.com")
        assertModelWithURL(URL(string: "https://example.com/path?test=true#fragment")!, matches: URL(string: "https://example.com")!, expectedDomain: "example.com")
    }
    
    func testWhenOriginalURLContainsWWW_ThenDomainDoesNotIncludeIt() {
        assertModelWithURL(URL(string: "http://www.example.com")!, matches: URL(string: "http://www.example.com")!, expectedDomain: "example.com")
    }

    func testWhenPrivatePlayerIsEnabled_ThenPrivatePlayerURLSetsDomainPlaceholder() {
        let model = HomePage.Models.RecentlyVisitedSiteModel(
            originalURL: .effectivePrivatePlayer("abcde12345"),
            privatePlayer: .mock(withMode: .enabled)
        )
        XCTAssertEqual(model?.isRealDomain, false)
        XCTAssertEqual(model?.domainToDisplay, PrivatePlayer.commonName)
    }

    func testWhenPrivatePlayerIsDisabled_ThenPrivatePlayerURLDoesNotSetDomainPlaceholder() {
        let url = URL.effectivePrivatePlayer("abcde12345")
        let model = HomePage.Models.RecentlyVisitedSiteModel(originalURL: url, privatePlayer: .mock(withMode: .disabled))
        XCTAssertEqual(model?.isRealDomain, true)
        XCTAssertEqual(model?.domainToDisplay, model?.domain)
    }

    private func assertModelWithURL(_ url: URL, matches expectedURL: URL, expectedDomain: String) {
        let model = HomePage.Models.RecentlyVisitedSiteModel(originalURL: url)
        XCTAssertEqual(model?.isRealDomain, true)
        XCTAssertEqual(model?.domain, expectedDomain)
        XCTAssertEqual(model?.url, expectedURL)
    }
}

private extension PrivatePlayer {

    static func mock(withMode mode: PrivatePlayerMode = .enabled) -> PrivatePlayer {
        let preferencesPersistor = PrivatePlayerPreferencesPersistorMock(privatePlayerMode: mode, youtubeOverlayInteracted: true)
        let preferences = PrivatePlayerPreferences(persistor: preferencesPersistor)
        return PrivatePlayer(preferences: preferences)
    }
}
