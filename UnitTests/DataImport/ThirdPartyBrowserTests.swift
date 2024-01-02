//
//  ThirdPartyBrowserTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class ThirdPartyBrowserTests: XCTestCase {

    private let mockApplicationSupportDirectoryName = UUID().uuidString

    override func setUp() {
        super.setUp()
        let defaultRootDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(mockApplicationSupportDirectoryName)
        try? FileManager.default.removeItem(at: defaultRootDirectoryURL)
    }

    override func tearDown() {
        super.tearDown()
        let defaultRootDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(mockApplicationSupportDirectoryName)
        try? FileManager.default.removeItem(at: defaultRootDirectoryURL)
    }

    func testWhenCreatingThirdPartyBrowser_AndValidBrowserIsProvided_ThenThirdPartyBrowserInitializationSucceeds() {
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .brave))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .chrome))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .edge))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .firefox))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .lastPass))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .onePassword7))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .onePassword8))
        XCTAssertNotNil(ThirdPartyBrowser.browser(for: .safari))

        XCTAssertNil(ThirdPartyBrowser.browser(for: .csv))
    }

    func testWhenCreatingThirdPartyBrowser_AndValidBrowserIsNotProvided_ThenThirdPartyBrowserInitializationFails() {
        XCTAssertNil(ThirdPartyBrowser.browser(for: .csv))
    }

    func testWhenGettingBrowserProfiles_AndFirefoxProfileExists_ThenFirefoxProfileIsReturned() throws {
        let defaultProfileName = "profile.default"
        let defaultReleaseProfileName = "profile.default-release"

        let mockApplicationSupportDirectory = FileSystem(rootDirectoryName: mockApplicationSupportDirectoryName) {
            Directory("Firefox") {
                Directory("Profiles") {
                    Directory(defaultReleaseProfileName) {
                        File("key4.db", contents: .copy(key4DatabaseURL()))
                        File("logins.json", contents: .copy(loginsURL()))
                    }

                    Directory(defaultProfileName) {
                        File("key3.db", contents: .copy(key4DatabaseURL()))
                        File("logins.json", contents: .copy(loginsURL()))
                    }
                }
            }
        }

        let mockApplicationSupportDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(mockApplicationSupportDirectoryName)
        try mockApplicationSupportDirectory.writeToTemporaryDirectory()

        let list = ThirdPartyBrowser.firefox.browserProfiles(applicationSupportURL: mockApplicationSupportDirectoryURL)

        let validProfiles = list.profiles.filter { $0.validateProfileData()?.containsValidData == true }
        XCTAssertEqual(validProfiles.count, 2)
        XCTAssertEqual(list.defaultProfile?.profileName, "default-release")
    }

    func testWhenGettingBrowserProfiles_AndFirefoxProfileOnlyHasBookmarksData_ThenFirefoxProfileIsReturned() throws {
        let defaultReleaseProfileName = "profile.default-release"

        let mockApplicationSupportDirectory = FileSystem(rootDirectoryName: mockApplicationSupportDirectoryName) {
            Directory("Firefox") {
                Directory("Profiles") {
                    Directory(defaultReleaseProfileName) {
                        File("places.sqlite", contents: .copy(bookmarksURL()))
                    }
                }
            }
        }

        let mockApplicationSupportDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(mockApplicationSupportDirectoryName)
        try mockApplicationSupportDirectory.writeToTemporaryDirectory()

        let list = ThirdPartyBrowser.firefox.browserProfiles(applicationSupportURL: mockApplicationSupportDirectoryURL)

        let validProfiles = list.profiles.filter { $0.validateProfileData()?.containsValidData == true }
        XCTAssertEqual(validProfiles.count, 1)
        XCTAssertEqual(list.defaultProfile?.profileName, "default-release")
    }

    private func key4DatabaseURL() -> URL {
        let bundle = Bundle(for: ThirdPartyBrowserTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData/No Primary Password/key4.db")
    }

    private func loginsURL() -> URL {
        let bundle = Bundle(for: ThirdPartyBrowserTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData/No Primary Password/logins.json")
    }

    private func bookmarksURL() -> URL {
        let bundle = Bundle(for: ThirdPartyBrowserTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData/places.sqlite")
    }

}
