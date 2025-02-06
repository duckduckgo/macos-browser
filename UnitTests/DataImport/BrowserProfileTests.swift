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
import BrowserServicesKit

class BrowserProfileTests: XCTestCase {

    let mockURL = URL(string: "/Users/Dax/Library/ApplicationSupport/BrowserCompany/Browser/")!

    func testWhenBrowserProfileHasURLWithNoLoginData_ThenHasLoginDataIsFalse() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        XCTAssertTrue(profile.validateProfileData()?.containsValidData == false)
    }

    func testWhenBrowserProfileHasURLWithChromiumLoginData_ThenHasLoginDataIsTrue() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        fileStore.directoryStorage[profileURL.absoluteString] = ["Login Data"]

        XCTAssertTrue(profile.validateProfileData()?.containsValidData == true)
    }

    func testWhenBrowserProfileHasURLWithFirefoxLoginData_ThenHasLoginDataIsTrue() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        fileStore.directoryStorage[profileURL.absoluteString] = ["key4.db"]
        XCTAssertTrue(profile.validateProfileData()?.containsValidData == false)

        fileStore.directoryStorage[profileURL.absoluteString] = ["logins.json"]
        XCTAssertTrue(profile.validateProfileData()?.containsValidData == false)

        fileStore.directoryStorage[profileURL.absoluteString] = ["logins.json", "key4.db"]
        XCTAssertTrue(profile.validateProfileData()?.containsValidData == true)
    }

    func testWhenGettingProfileName_AndProfileHasNoDetectedName_ThenTheDirectoryNameIsUsed() {
        let profileURL = profile(named: "Profile")
        let fileStore = FileStoreMock()
        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "Profile")
    }

    func testWhenGettingProfileName_AndProfileHasAccountName_AccountNameIsUsed() {
        let profileURL = profile(named: "Default")
        let fileStore = FileStoreMock()

        let json = """
        {
            "account_info": [
            {
                "email": "profile@duck.com",
                "full_name": "User Name",
            }
            ],
            "profile": {
                "name": "Profile 1"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "User Name (profile@duck.com)")
        XCTAssertNotNil(profile.profilePreferences?.profileName)
    }

    func testWhenGettingProfileName_AndProfileHasNoDetectedChromiumName_ThenDetectedNameIsUsed() {
        let profileURL = profile(named: "DirectoryName")
        let fileStore = FileStoreMock()

        let json = """
        {
            "account_info": [],
            "profile": {
                "name": "ChromeProfile"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "ChromeProfile")
        XCTAssertNotNil(profile.profilePreferences?.profileName)
    }

    func testWhenGettingProfileName_AndChromiumPreferencesAreDetected_AndProfileNameIsSystemProfile_ThenProfileHasDefaultProfileName() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let json = """
        {
            "profile": {
                "name": "ChromeProfile"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.profileName, "System Profile")
        XCTAssertEqual(profile.profilePreferences?.profileName, "ChromeProfile")
    }

    private func profile(named name: String) -> URL {
        return mockURL.appendingPathComponent(name)
    }

    func testWhenLastChromiumVersionIsPresentInProfile_InstalledAppsReturnsMajorVersion() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let json = """
        {
            "profile": {
                "created_by_version": "118.0.5993.54"
            },
            "extensions": {
                "last_chrome_version": "120.0.1111.42"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.appVersion, "118.0.5993.54")
        XCTAssertEqual(profile.installedAppsMajorVersionDescription(), "118")
        XCTAssertEqual(DataImport.Source.chrome.installedAppsMajorVersionDescription(selectedProfile: profile), "118")
    }

    func testWhenLastOperaVersionIsPresent_InstalledAppsReturnsMajorVersion() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let json = """
        {
            "profile": {
            },
            "extensions": {
                "last_opera_version": "117.0.5938.13"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.appVersion, "117.0.5938.13")
        XCTAssertEqual(profile.installedAppsMajorVersionDescription(), "117")
        XCTAssertEqual(DataImport.Source.chrome.installedAppsMajorVersionDescription(selectedProfile: profile), "117")
    }

    func testWhenLastChromiumVersionIsNotPresentInProfile_CreatedByVersionIsReturned() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let json = """
        {
            "profile": {
                "created_by_version": "118.0.5993.54"
            }
        }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.appVersion, "118.0.5993.54")
        XCTAssertEqual(profile.installedAppsMajorVersionDescription(), "118")
        XCTAssertEqual(DataImport.Source.chrome.installedAppsMajorVersionDescription(selectedProfile: profile), "118")
    }

    func testWhenFirefoxLastVersionIsPresentInProfile_LastVersionIsReturned() {
        let profileURL = profile(named: "Firefox.default")
        let fileStore = FileStoreMock()

        let conf = """
        [Compatibility]
          LastVersion = 118.0.1_20230927232528/20230927232528
        LastOSABI=Darwin_aarch64-gcc3
            LastPlatformDir=/Applications/Firefox.app/Contents/Resources
        LastAppDir=/Applications/Firefox.app/Contents/Resources/browser
        """

        fileStore.storage["compatibility.ini"] = conf.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["compatibility.ini"]

        let profile = DataImport.BrowserProfile(browser: .firefox, profileURL: profileURL, fileStore: fileStore)

        XCTAssertEqual(profile.appVersion, "118.0.1_20230927232528/20230927232528")
        XCTAssertEqual(profile.installedAppsMajorVersionDescription(), "118")
        XCTAssertEqual(DataImport.Source.chrome.installedAppsMajorVersionDescription(selectedProfile: profile), "118")
    }

    func testWhenNoVersionInProfile_InstalledAppsVersionsReturned() {
        let profileURL = profile(named: "System Profile")
        let fileStore = FileStoreMock()

        let json = """
        { "profile": {} }
        """

        fileStore.storage["Preferences"] = json.utf8data
        fileStore.directoryStorage[profileURL.absoluteString] = ["Preferences"]

        let profile = DataImport.BrowserProfile(browser: .chrome, profileURL: profileURL, fileStore: fileStore)

        XCTAssertNil(profile.appVersion)
        XCTAssertEqual(profile.installedAppsMajorVersionDescription()?.sorted(), DataImport.Source.chrome.installedAppsMajorVersionDescription(selectedProfile: profile)?.sorted())
    }

}
