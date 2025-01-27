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
    var continueSetUpCardsLastDemonstrated: Date?
    var continueSetUpCardsNumberOfDaysDemonstrated: Int
    var continueSetUpCardsClosed: Bool
    var isRecentActivityVisible: Bool
    var isPrivacyStatsVisible: Bool
    var isSearchBarVisible: Bool
    var showFullURL: Bool
    var currentThemeName: String
    var favoritesDisplayMode: String?
    var showBookmarksBar: Bool
    var bookmarksBarAppearance: BookmarksBarAppearance
    var homeButtonPosition: HomeButtonPosition
    var homePageCustomBackground: String?
    var centerAlignedBookmarksBar: Bool
    var didDismissHomePagePromotion: Bool
    var showTabsAndBookmarksBarOnFullScreen: Bool

    init(
        showFullURL: Bool = false,
        currentThemeName: String = ThemeName.systemDefault.rawValue,
        favoritesDisplayMode: String? = FavoritesDisplayMode.displayNative(.desktop).description,
        isContinueSetUpVisible: Bool = true,
        continueSetUpCardsLastDemonstrated: Date? = nil,
        continueSetUpCardsNumberOfDaysDemonstrated: Int = 0,
        continueSetUpCardsClosed: Bool = false,
        isFavoriteVisible: Bool = true,
        isRecentActivityVisible: Bool = true,
        isPrivacyStatsVisible: Bool = false,
        isSearchBarVisible: Bool = true,
        showBookmarksBar: Bool = true,
        bookmarksBarAppearance: BookmarksBarAppearance = .alwaysOn,
        homeButtonPosition: HomeButtonPosition = .right,
        homePageCustomBackground: String? = nil,
        centerAlignedBookmarksBar: Bool = true,
        didDismissHomePagePromotion: Bool = true,
        showTabsAndBookmarksBarOnFullScreen: Bool = false
    ) {
        self.showFullURL = showFullURL
        self.currentThemeName = currentThemeName
        self.favoritesDisplayMode = favoritesDisplayMode
        self.isContinueSetUpVisible = isContinueSetUpVisible
        self.continueSetUpCardsLastDemonstrated = continueSetUpCardsLastDemonstrated
        self.continueSetUpCardsNumberOfDaysDemonstrated = continueSetUpCardsNumberOfDaysDemonstrated
        self.continueSetUpCardsClosed = continueSetUpCardsClosed
        self.isFavoriteVisible = isFavoriteVisible
        self.isRecentActivityVisible = isRecentActivityVisible
        self.isPrivacyStatsVisible = isPrivacyStatsVisible
        self.isSearchBarVisible = isSearchBarVisible
        self.showBookmarksBar = showBookmarksBar
        self.bookmarksBarAppearance = bookmarksBarAppearance
        self.homeButtonPosition = homeButtonPosition
        self.homePageCustomBackground = homePageCustomBackground
        self.centerAlignedBookmarksBar = centerAlignedBookmarksBar
        self.didDismissHomePagePromotion = didDismissHomePagePromotion
        self.showTabsAndBookmarksBarOnFullScreen = showTabsAndBookmarksBarOnFullScreen
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
                isPrivacyStatsVisible: false,
                homeButtonPosition: .left,
                homePageCustomBackground: CustomBackground.gradient(.gradient01).description,
                centerAlignedBookmarksBar: true,
                showTabsAndBookmarksBarOnFullScreen: false
            )
        )

        XCTAssertEqual(model.showFullURL, false)
        XCTAssertEqual(model.currentThemeName, ThemeName.systemDefault)
        XCTAssertEqual(model.favoritesDisplayMode, .displayNative(.desktop))
        XCTAssertEqual(model.isFavoriteVisible, true)
        XCTAssertEqual(model.isContinueSetUpVisible, true)
        XCTAssertEqual(model.isRecentActivityVisible, true)
        XCTAssertEqual(model.isPrivacyStatsVisible, false)
        XCTAssertEqual(model.isSearchBarVisible, true)
        XCTAssertEqual(model.homeButtonPosition, .left)
        XCTAssertEqual(model.homePageCustomBackground, .gradient(.gradient01))
        XCTAssertTrue(model.centerAlignedBookmarksBarBool)
        XCTAssertFalse(model.showTabsAndBookmarksBarOnFullScreen)

        model = AppearancePreferences(
            persistor: AppearancePreferencesPersistorMock(
                showFullURL: true,
                currentThemeName: ThemeName.light.rawValue,
                favoritesDisplayMode: FavoritesDisplayMode.displayUnified(native: .desktop).description,
                isContinueSetUpVisible: false,
                isFavoriteVisible: false,
                isRecentActivityVisible: false,
                isPrivacyStatsVisible: true,
                isSearchBarVisible: false,
                homeButtonPosition: .left,
                homePageCustomBackground: CustomBackground.gradient(.gradient05).description,
                centerAlignedBookmarksBar: false,
                showTabsAndBookmarksBarOnFullScreen: true
            )
        )
        XCTAssertEqual(model.showFullURL, true)
        XCTAssertEqual(model.currentThemeName, ThemeName.light)
        XCTAssertEqual(model.favoritesDisplayMode, .displayUnified(native: .desktop))
        XCTAssertEqual(model.isFavoriteVisible, false)
        XCTAssertEqual(model.isContinueSetUpVisible, false)
        XCTAssertEqual(model.isRecentActivityVisible, false)
        XCTAssertEqual(model.isPrivacyStatsVisible, true)
        XCTAssertEqual(model.isSearchBarVisible, false)
        XCTAssertEqual(model.homeButtonPosition, .left)
        XCTAssertEqual(model.homePageCustomBackground, .gradient(.gradient05))
        XCTAssertFalse(model.centerAlignedBookmarksBarBool)
        XCTAssertTrue(model.showTabsAndBookmarksBarOnFullScreen)
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
        model.isPrivacyStatsVisible = true
        XCTAssertEqual(model.isPrivacyStatsVisible, true)
        model.isFavoriteVisible = true
        XCTAssertEqual(model.isFavoriteVisible, true)
        model.isContinueSetUpVisible = true
        XCTAssertEqual(model.isContinueSetUpVisible, true)
        model.isSearchBarVisible = true
        XCTAssertEqual(model.isSearchBarVisible, true)

        model.isRecentActivityVisible = false
        XCTAssertEqual(model.isRecentActivityVisible, false)
        model.isPrivacyStatsVisible = false
        XCTAssertEqual(model.isPrivacyStatsVisible, false)
        model.isFavoriteVisible = false
        XCTAssertEqual(model.isFavoriteVisible, false)
        model.isContinueSetUpVisible = false
        XCTAssertEqual(model.isContinueSetUpVisible, false)
        model.isSearchBarVisible = false
        XCTAssertEqual(model.isSearchBarVisible, false)
    }

    func testPersisterReturnsValuesFromDisk() {
        UserDefaultsWrapper<Any>.clearAll()
        let persister1 = AppearancePreferencesUserDefaultsPersistor()
        let persister2 = AppearancePreferencesUserDefaultsPersistor()

        persister2.isFavoriteVisible = false
        persister1.isFavoriteVisible = true
        persister2.isRecentActivityVisible = false
        persister1.isRecentActivityVisible = true
        persister2.isPrivacyStatsVisible = false
        persister1.isPrivacyStatsVisible = true
        persister2.isContinueSetUpVisible = false
        persister1.isContinueSetUpVisible = true
        persister2.isSearchBarVisible = false
        persister1.isSearchBarVisible = true

        XCTAssertTrue(persister2.isFavoriteVisible)
        XCTAssertTrue(persister2.isRecentActivityVisible)
        XCTAssertTrue(persister2.isPrivacyStatsVisible)
        XCTAssertTrue(persister2.isContinueSetUpVisible)
        XCTAssertTrue(persister2.isSearchBarVisible)
    }

    func testContinueSetUpIsNotDismissedAfterSeveralDemonstrationsWithinSeveralDays() {
        // 1. app installed and launched
        var now = Date()

        // listen to AppearancePreferences.objectWillChange
        let model = AppearancePreferences(persistor: AppearancePreferencesPersistorMock(), dateTimeProvider: { now })
        let c = model.objectWillChange.sink {
            XCTFail("Unexpected model.objectWillChange")
        }
        func incrementDate() {
            now = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        }

        // check during N hours
        // eObjectWillChange shouldn‘t be called until N days
        for i in 0..<max(AppearancePreferences.Constants.dismissNextStepsCardsAfterDays, 48) {
            XCTAssertTrue(model.isContinueSetUpVisible, "\(i)")
            XCTAssertFalse(model.isContinueSetUpCardsViewOutdated, "\(i)")
            incrementDate()
        }

        withExtendedLifetime(c) {}
    }

    func testContinueSetUpIsDismissedAfterNDays() {
        // 1. app installed and launched
        var now = Date()

        // listen to AppearancePreferences.objectWillChange
        let model = AppearancePreferences(persistor: AppearancePreferencesPersistorMock(), dateTimeProvider: { now })
        var eObjectWillChange: XCTestExpectation!
        let c = model.objectWillChange.sink {
            eObjectWillChange.fulfill()
        }
        func incrementDate() {
            now = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        }

        // check during N days
        // eObjectWillChange shouldn‘t be called until N days
        for i in 0..<AppearancePreferences.Constants.dismissNextStepsCardsAfterDays {
            XCTAssertTrue(model.isContinueSetUpVisible, "\(i)")
            XCTAssertFalse(model.isContinueSetUpCardsViewOutdated, "\(i)")
            model.continueSetUpCardsViewDidAppear()
            incrementDate()
        }
        // N days passed
        // eObjectWillChange should be called once
        eObjectWillChange = expectation(description: "AppearancePreferences.objectWillChange called")
        incrementDate()
        model.continueSetUpCardsViewDidAppear()
        XCTAssertFalse(model.isContinueSetUpVisible, "dismissNextStepsCardsAfterDays")
        waitForExpectations(timeout: 1)

        // shouldn‘t change after being set once
        for i in (AppearancePreferences.Constants.dismissNextStepsCardsAfterDays + 1)..<(AppearancePreferences.Constants.dismissNextStepsCardsAfterDays + 20) {
            XCTAssertFalse(model.isContinueSetUpVisible, "\(i)")
            XCTAssertTrue(model.isContinueSetUpCardsViewOutdated, "\(i)")
            incrementDate()
            model.continueSetUpCardsViewDidAppear()
        }

        withExtendedLifetime(c) {}
    }

}
