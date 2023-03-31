//
//  AppearancePreferencesTests.swift
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

struct AppearancePreferencesPersistorMock: AppearancePreferencesPersistor {
    var showFullURL: Bool
    var showAutocompleteSuggestions: Bool
    var currentThemeName: String
    var defaultPageZoom: CGFloat

    init(
        showFullURL: Bool = false,
        showAutocompleteSuggestions: Bool = true,
        currentThemeName: String = ThemeName.systemDefault.rawValue,
        defaultPageZoom: CGFloat = DefaultZoomValue.percent100.rawValue
    ) {
        self.showFullURL = showFullURL
        self.showAutocompleteSuggestions = showAutocompleteSuggestions
        self.currentThemeName = currentThemeName
        self.defaultPageZoom = defaultPageZoom
    }
}

final class AppearancePreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: false,
                showAutocompleteSuggestions: true,
                currentThemeName: ThemeName.systemDefault.rawValue,
                defaultPageZoom: DefaultZoomValue.percent100.rawValue
            )
        )

        XCTAssertEqual(model.showFullURL, false)
        XCTAssertEqual(model.showAutocompleteSuggestions, true)
        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent100)

        model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: true,
                showAutocompleteSuggestions: false,
                currentThemeName: ThemeName.light.rawValue,
                defaultPageZoom: DefaultZoomValue.percent50.rawValue
            )
        )
        XCTAssertEqual(model.showFullURL, true)
        XCTAssertEqual(model.showAutocompleteSuggestions, false)
        XCTAssertEqual(model.currentThemeName, ThemeName.light)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent50)
    }

    func testWhenInitializedWithGarbageThenThemeIsSetToSystemDefault() throws {
        let model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                currentThemeName: "garbage"
            )
        )

        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
    }

    func testThemeNameReturnsCorrectAppearanceObject() throws {
        XCTAssertEqual(ThemeName.systemDefault.appearance, nil)
        XCTAssertEqual(ThemeName.light.appearance, NSAppearance(named: .aqua))
        XCTAssertEqual(ThemeName.dark.appearance, NSAppearance(named: .darkAqua))
    }

    func testWhenThemeNameIsUpdatedThenApplicationAppearanceIsUpdated() throws {
        let model = AppearancePreferences(persistor: AppearancePreferencesPersistorMock())

        model.currentThemeName = ThemeName.systemDefault
        XCTAssertEqual(NSApp.appearance?.name, ThemeName.systemDefault.appearance?.name)

        model.currentThemeName = ThemeName.light
        XCTAssertEqual(NSApp.appearance?.name, ThemeName.light.appearance?.name)

        model.currentThemeName = ThemeName.dark
        XCTAssertEqual(NSApp.appearance?.name, ThemeName.dark.appearance?.name)

        model.currentThemeName = ThemeName.systemDefault
        XCTAssertEqual(NSApp.appearance?.name, ThemeName.systemDefault.appearance?.name)
    }

    func testWhenZoomLevelChangedInAppearancePreferencesThenThePersisterAndUserDefaultsZoomValuesAreUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        let persister = AppearancePreferencesUserDefaultsPersistor()
        let model = AppearancePreferences(persistor: persister)
        model.defaultPageZoom = randomZoomLevel

        XCTAssertEqual(persister.defaultPageZoom, randomZoomLevel.rawValue)
        let savedZoomValue = UserDefaultsWrapper(key: .defaultPageZoom, defaultValue: DefaultZoomValue.percent100.rawValue).wrappedValue
        XCTAssertEqual(savedZoomValue, randomZoomLevel.rawValue)
    }
}
