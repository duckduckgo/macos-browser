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
    var zoomPerWebsite: [String: CGFloat]
    var showBookmarksBar: Bool
    var bookmarksBarAppearance: BookmarksBarAppearance
    var homeButtonPosition: HomeButtonPosition

    init(
        showFullURL: Bool = false,
        showAutocompleteSuggestions: Bool = true,
        currentThemeName: String = ThemeName.systemDefault.rawValue,
        defaultPageZoom: CGFloat = DefaultZoomValue.percent100.rawValue,
        zoomPerWebsite: [String: CGFloat] = [:],
        isContinueSetUpVisible: Bool = true,
        isFavoriteVisible: Bool = true,
        isRecentActivityVisible: Bool = true,
        showBookmarksBar: Bool = true,
        bookmarksBarAppearance: BookmarksBarAppearance = .alwaysOn,
        homeButtonPosition: HomeButtonPosition = .right
    ) {
        self.showFullURL = showFullURL
        self.showAutocompleteSuggestions = showAutocompleteSuggestions
        self.currentThemeName = currentThemeName
        self.defaultPageZoom = defaultPageZoom
        self.zoomPerWebsite = zoomPerWebsite
        self.isContinueSetUpVisible = isContinueSetUpVisible
        self.isFavoriteVisible = isFavoriteVisible
        self.isRecentActivityVisible = isRecentActivityVisible
        self.showBookmarksBar = showBookmarksBar
        self.bookmarksBarAppearance = bookmarksBarAppearance
        self.homeButtonPosition = homeButtonPosition
    }
}

final class AppearancePreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        let zoomDictionary: [String: DefaultZoomValue] = ["bbc.co.uk": DefaultZoomValue.percent150, "duckduckgo.com": DefaultZoomValue.percent75]
        var model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: false,
                showAutocompleteSuggestions: true,
                currentThemeName: ThemeName.systemDefault.rawValue,
                defaultPageZoom: DefaultZoomValue.percent100.rawValue,
                zoomPerWebsite: zoomDictionary.mapValues { $0.rawValue },
                isContinueSetUpVisible: true,
                isFavoriteVisible: true,
                isRecentActivityVisible: true,
                homeButtonPosition: .left
            )
        )

        XCTAssertEqual(model.showFullURL, false)
        XCTAssertEqual(model.showAutocompleteSuggestions, true)
        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent100)
        XCTAssertEqual(model.zoomPerWebsite, zoomDictionary)
        XCTAssertEqual(model.isFavoriteVisible, true)
        XCTAssertEqual(model.isContinueSetUpVisible, true)
        XCTAssertEqual(model.isRecentActivityVisible, true)
        XCTAssertEqual(model.homeButtonPosition, .left)

        model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: true,
                showAutocompleteSuggestions: false,
                currentThemeName: ThemeName.light.rawValue,
                defaultPageZoom: DefaultZoomValue.percent50.rawValue,
                isContinueSetUpVisible: false,
                isFavoriteVisible: false,
                isRecentActivityVisible: false,
                homeButtonPosition: .left
            )
        )
        XCTAssertEqual(model.showFullURL, true)
        XCTAssertEqual(model.showAutocompleteSuggestions, false)
        XCTAssertEqual(model.currentThemeName, ThemeName.light)
        XCTAssertEqual(model.defaultPageZoom, DefaultZoomValue.percent50)
        XCTAssertEqual(model.isFavoriteVisible, false)
        XCTAssertEqual(model.isContinueSetUpVisible, false)
        XCTAssertEqual(model.isRecentActivityVisible, false)
        XCTAssertEqual(model.homeButtonPosition, .left)
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

    func testWhenZoomLevelPerWebsiteChangedInAppearancePreferencesThenThePersisterAndUserDefaultsZoomPerWebsiteValuesAreUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        let zoomDictionary: [String: DefaultZoomValue] = ["bbc.co.uk": DefaultZoomValue.percent150, "duckduckgo.com": DefaultZoomValue.percent75]
        let persister = AppearancePreferencesUserDefaultsPersistor()
        let model = AppearancePreferences(persistor: persister)
        model.zoomPerWebsite = zoomDictionary

        XCTAssertEqual(persister.zoomPerWebsite, zoomDictionary.mapValues { $0.rawValue })
        let savedZoomPerWebsiteValues = UserDefaultsWrapper(key: .websitePageZoom, defaultValue: [:]).wrappedValue as? [String: CGFloat]
        XCTAssertEqual(savedZoomPerWebsiteValues, zoomDictionary.mapValues { $0.rawValue })
    }

    func testWhenUpdatingZoomPerWebsiteThenThePersisterAndUserDefaultsZoomPerWebsiteValuesAreUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        var zoomDictionary: [String: DefaultZoomValue] = ["provola.co.uk": DefaultZoomValue.percent200, "affumicata.it": DefaultZoomValue.percent50]
        let persister = AppearancePreferencesUserDefaultsPersistor()
        let model = AppearancePreferences(persistor: persister)
        model.zoomPerWebsite = zoomDictionary

        model.updateZoomPerWebsite(zoomLevel: .percent125, website: "test.com")
        zoomDictionary.updateValue(.percent125, forKey: "test.com")

        XCTAssertEqual(persister.zoomPerWebsite, zoomDictionary.mapValues { $0.rawValue })
        let savedZoomPerWebsiteValues = UserDefaultsWrapper(key: .websitePageZoom, defaultValue: [:]).wrappedValue as? [String: CGFloat]
        XCTAssertEqual(savedZoomPerWebsiteValues, zoomDictionary.mapValues { $0.rawValue })
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
