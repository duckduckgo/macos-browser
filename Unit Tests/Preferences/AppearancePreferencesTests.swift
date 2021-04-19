//
//  AppearancePreferencesTests.swift
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

final class AppearancePreferencesTests: XCTestCase {

    private let testGroupName = "test"

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: testGroupName)?.removePersistentDomain(forName: testGroupName)
    }

    func testWhenGettingNSAppearanceFromThemeThenAppearanceMatchesTheme() {
        let darkTheme = ThemeName.dark
        let lightTheme = ThemeName.light
        let systemTheme = ThemeName.systemDefault

        XCTAssertEqual(darkTheme.appearance, NSAppearance(named: .darkAqua))
        XCTAssertEqual(lightTheme.appearance, NSAppearance(named: .aqua))
        XCTAssertNil(systemTheme.appearance)
    }

    func testWhenSettingCurrentThemeThenThemeIsPersisted() {
        var appearancePreferences = createAppearancePreferences()

        XCTAssertEqual(appearancePreferences.currentThemeName, .systemDefault)

        appearancePreferences.currentThemeName = .dark
        XCTAssertEqual(appearancePreferences.currentThemeName, .dark)

        appearancePreferences.currentThemeName = .light
        XCTAssertEqual(appearancePreferences.currentThemeName, .light)

        appearancePreferences.currentThemeName = .systemDefault
        XCTAssertEqual(appearancePreferences.currentThemeName, .systemDefault)
    }

    func testWhenReadingCurrentThemeDefaultThenSystemAppearanceIsReturned() {
        let appearancePreferences = createAppearancePreferences()
        XCTAssertEqual(appearancePreferences.currentThemeName, .systemDefault)
    }

    private func createAppearancePreferences() -> AppearancePreferences {
        let testUserDefaults = UserDefaults(suiteName: testGroupName)
        return AppearancePreferences(userDefaults: testUserDefaults!)
    }

}
