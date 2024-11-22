//
//  UserAgentTests.swift
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

import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class UserAgentTests: XCTestCase {

    func testThatDefaultUserAgentIsBranded() {
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "http://localhost")!))
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "http://example.com")!))
    }

    func testWhenDomainIsGoogleDocsThenUserAgentIsBranded() {
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "https://google.com")!))
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "https://accounts.google.com")!))
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "https://docs.google.com")!))
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "https://docs.google.com/spreadsheets/a/document")!))
        XCTAssertEqual(UserAgent.brandedDefault, UserAgent.for(URL(string: "https://a.docs.google.com")!))
    }

    func testWhenDomainIsDuckDuckGo_ThenUserAgentDoesNotIncludeChrome() {
        XCTAssertFalse(UserAgent.for(URL.duckDuckGo).contains("Chrome"))
    }

    func testWhenUserAgentIsDuckDuckGo_ThenUserAgentContainsExpectedParameters() {
        let appVersion = "app_version"
        let appID = "app_id"
        let systemVersion = "system_version"
        let userAgent = UserAgent.duckDuckGoUserAgent(appVersion: appVersion, appID: appID, systemVersion: systemVersion)

        XCTAssertEqual(userAgent, "ddg_mac/\(appVersion) (\(appID); macOS \(systemVersion))")
    }

    func testWhenURLDomainIsOnDefaultSitesListThenUserAgentIsSafari() {
        let config = MockPrivacyConfiguration()
        config.featureSettings = [
            "defaultSites": [
                [
                    "domain": "wikipedia.org",
                    "reason": "reason"
                ],
                [
                    "domain": "google.com",
                    "reason": "reason"
                ]
            ]
        ] as! [String: Any]

        XCTAssertEqual(UserAgent.for("http://wikipedia.org".url, privacyConfig: config), UserAgent.safari)
        XCTAssertEqual(UserAgent.for("https://wikipedia.org".url, privacyConfig: config), UserAgent.safari)
        XCTAssertEqual(UserAgent.for("https://en.wikipedia.org/wiki/Duck".url, privacyConfig: config), UserAgent.safari)
        XCTAssertEqual(UserAgent.for("https://google.com".url, privacyConfig: config), UserAgent.safari)
        XCTAssertEqual(UserAgent.for("https://docs.google.com".url, privacyConfig: config), UserAgent.safari)
        XCTAssertNotEqual(UserAgent.for("https://duckduckgo.com".url, privacyConfig: config), UserAgent.safari)
    }

    func testWhenURLDomainIsOnWebViewDefaultListThenUserAgentIsWebKitDefault() {
        let config = MockPrivacyConfiguration()
        config.featureSettings = [
            "webViewDefault": [
                [
                    "domain": "wikipedia.org",
                    "reason": "reason"
                ],
                [
                    "domain": "google.com",
                    "reason": "reason"
                ]
            ]
        ] as! [String: Any]

        XCTAssertEqual(UserAgent.for("http://wikipedia.org".url, privacyConfig: config), UserAgent.webViewDefault)
        XCTAssertEqual(UserAgent.for("https://wikipedia.org".url, privacyConfig: config), UserAgent.webViewDefault)
        XCTAssertEqual(UserAgent.for("https://en.wikipedia.org/wiki/Duck".url, privacyConfig: config), UserAgent.webViewDefault)
        XCTAssertEqual(UserAgent.for("https://google.com".url, privacyConfig: config), UserAgent.webViewDefault)
        XCTAssertEqual(UserAgent.for("https://docs.google.com".url, privacyConfig: config), UserAgent.webViewDefault)
        XCTAssertNotEqual(UserAgent.for("https://duckduckgo.com".url, privacyConfig: config), UserAgent.webViewDefault)
    }

    func testThatRemoteConfigurationTakesPrecedenceOverLocalConfiguration() {
        let config = MockPrivacyConfiguration()

        XCTAssertEqual(UserAgent.for("http://duckduckgo.com".url, privacyConfig: config), UserAgent.default)

        config.featureSettings = [
            "webViewDefault": [
                [
                    "domain": "duckduckgo.com",
                    "reason": "reason"
                ]
            ]
        ] as! [String: Any]

        XCTAssertEqual(UserAgent.for("http://duckduckgo.com".url, privacyConfig: config), UserAgent.webViewDefault)
    }

}
