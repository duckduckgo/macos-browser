//
//  BrowserProfileTests.swift
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

class BrowserProfileListTests: XCTestCase {

    let mockURL = URL(string: "/Users/Dax/Library/ApplicationSupport/BrowserCompany/Browser/")!

    func testWhenBrowserProfileHasURLWithNoLoginData_ThenHasLoginDataIsFalse() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        XCTAssertFalse(profile.hasBrowserData)
    }

    func testWhenBrowserProfileHasURLWithChromiumLoginData_ThenHasLoginDataIsTrue() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        fileStore.directoryStorage[profileURL.absoluteString] = ["Login Data"]

        XCTAssertTrue(profile.hasBrowserData)
    }

    func testWhenBrowserProfileHasURLWithFirefoxLoginData_ThenHasLoginDataIsTrue() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        fileStore.directoryStorage[profileURL.absoluteString] = ["key4.db"]
        XCTAssertFalse(profile.hasBrowserData)

        fileStore.directoryStorage[profileURL.absoluteString] = ["logins.json"]
        XCTAssertFalse(profile.hasBrowserData)

        fileStore.directoryStorage[profileURL.absoluteString] = ["logins.json", "key4.db"]
        XCTAssertTrue(profile.hasBrowserData)
    }

    func testWhenGettingProfileName_AndProfileHasNoDetectedName_ThenTheDirectoryNameIsUsed() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "Profile")
    }

    func testWhenGettingProfileName_AndProfileHasNoDetectedChromiumName_ThenDetectedNameIsUsed() {
        let profileURL = profile(named: "DirectoryName")
        let fileStore = FileStoreMock()

        let chromiumPreferences = ChromePreferences(profile: .init(name: "ChromeProfile"))
        guard let chromiumPreferencesData = try? JSONEncoder().encode(chromiumPreferences) else {
            XCTFail("Failed to encode Chromium preferences object")
            return
        }

        fileStore.storage["Preferences"] = chromiumPreferencesData
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "ChromeProfile")
        XCTAssertTrue(profile.hasNonDefaultProfileName)
    }

    func testWhenGettingProfileName_AndChromiumPreferencesAreDetected_AndProfileNameIsSystemProfile_ThenProfileHasDefaultProfileName() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let chromiumPreferences = ChromePreferences(profile: .init(name: "ChromeProfile"))
        guard let chromiumPreferencesData = try? JSONEncoder().encode(chromiumPreferences) else {
            XCTFail("Failed to encode Chromium preferences object")
            return
        }

        fileStore.storage["Preferences"] = chromiumPreferencesData
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "System Profile")
        XCTAssertFalse(profile.hasNonDefaultProfileName)
    }

    private func profile(named name: String) -> URL {
        return mockURL.appendingPathComponent(name)
    }

}
