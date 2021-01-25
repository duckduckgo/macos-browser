//
//  AppUserDefaultsTests.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

class AppUserDefaultsTests: XCTestCase {
    let testSuiteName = "test"

    override func setUp() {
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)
    }

    func testWhenRestoreSessionAtLaunchIsSetThenItIsPersisted() {
        let appUserDefaults = UserDefaults(suiteName: testSuiteName)!

        appUserDefaults.restoreSessionAtLaunch = .never
        XCTAssertEqual(appUserDefaults.restoreSessionAtLaunch, .never)

        appUserDefaults.restoreSessionAtLaunch = .always
        XCTAssertEqual(appUserDefaults.restoreSessionAtLaunch, .always)

        appUserDefaults.restoreSessionAtLaunch = .systemDefined
        XCTAssertEqual(appUserDefaults.restoreSessionAtLaunch, .systemDefined)
    }

    func testWhenSettingsIsNewThenDefaultForRestoreSessionAtLaunchIsSystemDefined() {

        let appUserDefaults = UserDefaults(suiteName: testSuiteName)!
        XCTAssertEqual(appUserDefaults.restoreSessionAtLaunch, .systemDefined)

    }
    
}
