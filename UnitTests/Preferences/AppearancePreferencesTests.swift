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
    var isFavoriteVisible: Bool
    var isContinueSetUpVisible: Bool
    var isRecentActivityVisible: Bool
    var showFullURL: Bool
    var showAutocompleteSuggestions: Bool
    var currentThemeName: String
    var defaultPageZoom: CGFloat

    init(
        showFullURL: Bool = false,
        showAutocompleteSuggestions: Bool = true,
        currentThemeName: String = ThemeName.systemDefault.rawValue,
        defaultPageZoom: CGFloat = DefaultZoomValue.percent100.rawValue,
        isContinueSetUpVisible: Bool = true,
        isFavoriteVisible: Bool = true,
        isRecentActivityVisible: Bool = true
    ) {
        self.showFullURL = showFullURL
        self.showAutocompleteSuggestions = showAutocompleteSuggestions
        self.currentThemeName = currentThemeName
        self.defaultPageZoom = defaultPageZoom
        self.isContinueSetUpVisible = isContinueSetUpVisible
        self.isFavoriteVisible = isFavoriteVisible
        self.isRecentActivityVisible = isRecentActivityVisible
    }
}

final class AppearancePreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: false,
                showAutocompleteSuggestions: true,
                currentThemeName: ThemeName.systemDefault.rawValue,
                defaultPageZoom: DefaultZoomValue.percent100.rawValue,
                isContinueSetUpVisible: true,
                isFavoriteVisible: true,
                isRecentActivityVisible: true
            )
        )

        XCTAssertEqual(model.showFullURL, false)
        XCTAssertEqual(model.showAutocompleteSuggestions, true)
        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent100)
        XCTAssertEqual(model.isFavoriteVisible, true)
        XCTAssertEqual(model.isContinueSetUpVisible, true)
        XCTAssertEqual(model.isRecentActivityVisible, true)

        model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: true,
                showAutocompleteSuggestions: false,
                currentThemeName: ThemeName.light.rawValue,
                defaultPageZoom: DefaultZoomValue.percent50.rawValue,
                isContinueSetUpVisible: false,
                isFavoriteVisible: false,
                isRecentActivityVisible: false
            )
        )
        XCTAssertEqual(model.showFullURL, true)
        XCTAssertEqual(model.showAutocompleteSuggestions, false)
        XCTAssertEqual(model.currentThemeName, ThemeName.light)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent50)
        XCTAssertEqual(model.isFavoriteVisible, false)
        XCTAssertEqual(model.isContinueSetUpVisible, false)
        XCTAssertEqual(model.isRecentActivityVisible, false)
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

    func testWhenNewTabPreferencesAreUpdatedThenPersistedValuesAreUpdated() throws {
        let model = AppearancePreferences(persistor: AppearancePreferencesPersistorMock())

        model.isRecentActivityVisible = true
        XCTAssertEqual(model.isRecentActivityVisible, true)
        model.isFavoriteVisible = true
        XCTAssertEqual(model.isFavoriteVisible, true)
        model.isContinueSetUpVisible = true
        XCTAssertEqual(model.isContinueSetUpVisible, true)

        model.isRecentActivityVisible = false
        XCTAssertEqual(model.isRecentActivityVisible, false)
        model.isFavoriteVisible = false
        XCTAssertEqual(model.isFavoriteVisible, false)
        model.isContinueSetUpVisible = false
        XCTAssertEqual(model.isContinueSetUpVisible, false)
    }

    func testPersisterReturnsValuesFromDisk() {
        UserDefaultsWrapper<Any>.clearAll()
        var persister1 = AppearancePreferencesUserDefaultsPersistor()
        var persister2 = AppearancePreferencesUserDefaultsPersistor()

        persister2.isFavoriteVisible = false
        persister1.isFavoriteVisible = true
        persister2.isRecentActivityVisible = false
        persister1.isRecentActivityVisible = true
        persister2.isContinueSetUpVisible = false
        persister1.isContinueSetUpVisible = true

        XCTAssertTrue(persister2.isFavoriteVisible)
        XCTAssertTrue(persister2.isRecentActivityVisible)
        XCTAssertTrue(persister2.isContinueSetUpVisible)
    }
}
