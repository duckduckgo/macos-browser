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

import Bookmarks
import XCTest
@testable import DuckDuckGo_Privacy_Browser

struct AppearancePreferencesPersistorMock: AppearancePreferencesPersistor {
    var isFavoriteVisible: Bool
    var isContinueSetUpVisible: Bool
    var isRecentActivityVisible: Bool
    var showFullURL: Bool
    var currentThemeName: String
    var favoritesDisplayMode: String?
    var showBookmarksBar: Bool
    var bookmarksBarAppearance: BookmarksBarAppearance
    var homeButtonPosition: HomeButtonPosition

    init(
        showFullURL: Bool = false,
        currentThemeName: String = ThemeName.systemDefault.rawValue,
        favoritesDisplayMode: String? = FavoritesDisplayMode.displayNative(.desktop).description,
        isContinueSetUpVisible: Bool = true,
        isFavoriteVisible: Bool = true,
        isRecentActivityVisible: Bool = true,
        showBookmarksBar: Bool = true,
        bookmarksBarAppearance: BookmarksBarAppearance = .alwaysOn,
        homeButtonPosition: HomeButtonPosition = .right
    ) {
        self.showFullURL = showFullURL
        self.currentThemeName = currentThemeName
        self.favoritesDisplayMode = favoritesDisplayMode
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
        var model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: false,
                currentThemeName: ThemeName.systemDefault.rawValue,
                favoritesDisplayMode: FavoritesDisplayMode.displayNative(.desktop).description,
                isContinueSetUpVisible: true,
                isFavoriteVisible: true,
                isRecentActivityVisible: true,
                homeButtonPosition: .left
            )
        )

        XCTAssertEqual(model.showFullURL, false)
        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
        XCTAssertEqual(model.favoritesDisplayMode, .displayNative(.desktop))
        XCTAssertEqual(model.isFavoriteVisible, true)
        XCTAssertEqual(model.isContinueSetUpVisible, true)
        XCTAssertEqual(model.isRecentActivityVisible, true)
        XCTAssertEqual(model.homeButtonPosition, .left)

        model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: true,
                currentThemeName: ThemeName.light.rawValue,
                favoritesDisplayMode: FavoritesDisplayMode.displayUnified(native: .desktop).description,
                isContinueSetUpVisible: false,
                isFavoriteVisible: false,
                isRecentActivityVisible: false,
                homeButtonPosition: .left
            )
        )
        XCTAssertEqual(model.showFullURL, true)
        XCTAssertEqual(model.currentThemeName, ThemeName.light)
        XCTAssertEqual(model.favoritesDisplayMode, .displayUnified(native: .desktop))
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
        let persister1 = AppearancePreferencesUserDefaultsPersistor()
        let persister2 = AppearancePreferencesUserDefaultsPersistor()

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
