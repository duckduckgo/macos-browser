//
//  StartupPreferencesTests.swift
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

struct StartupPreferencesPersistorMock: StartupPreferencesPersistor {
    var launchToCustomHomePage: Bool
    var customHomePageURL: String
    var restorePreviousSession: Bool

    init(launchToCustomHomePage: Bool, customHomePageURL: String, restorePreviousSession: Bool = false) {
        self.customHomePageURL = customHomePageURL
        self.launchToCustomHomePage = launchToCustomHomePage
        self.restorePreviousSession = restorePreviousSession
    }
}

class StartupPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: false, customHomePageURL: "duckduckgo.com", restorePreviousSession: false))
        XCTAssertEqual(model.launchToCustomHomePage, false)
        XCTAssertEqual(model.customHomePageURL, "duckduckgo.com")
        XCTAssertEqual(model.restorePreviousSession, false)

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "http://duckduckgo.com", restorePreviousSession: true))
        XCTAssertEqual(model.launchToCustomHomePage, true)
        XCTAssertEqual(model.customHomePageURL, "http://duckduckgo.com")
        XCTAssertEqual(model.restorePreviousSession, true)

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "https://duckduckgo.com", restorePreviousSession: true))
        XCTAssertEqual(model.customHomePageURL, "https://duckduckgo.com")

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "https://mail.google.com/mail/u/1/#spam/FMfcgzGtxKRZFPXfxKMWSKVgwJlswxnH", restorePreviousSession: true))
        XCTAssertEqual(model.friendlyURL, "https://mail.google.com/mai...")

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "https://www.rnids.rs/национални-домени/регистрација-националних-домена", restorePreviousSession: true))
        XCTAssertEqual(model.friendlyURL, "https://www.rnids.rs/национ...")

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "www.rnids.rs/национални-домени/регистрација-националних-домена", restorePreviousSession: true))
        XCTAssertEqual(model.friendlyURL, "www.rnids.rs/национални-дом...")

        model = StartupPreferences(persistor: StartupPreferencesPersistorMock(launchToCustomHomePage: true, customHomePageURL: "https://💩.la", restorePreviousSession: true))
        XCTAssertEqual(model.friendlyURL, "https://💩.la")

    }

    func testIsValidURL() {
        XCTAssertFalse(StartupPreferences().isValidURL("invalid url"))
        XCTAssertFalse(StartupPreferences().isValidURL("invalidUrl"))
        XCTAssertFalse(StartupPreferences().isValidURL(""))
        XCTAssertTrue(StartupPreferences().isValidURL("test.com"))
        XCTAssertTrue(StartupPreferences().isValidURL("http://test.com"))
        XCTAssertTrue(StartupPreferences().isValidURL("https://test.com"))
    }

}
