//
//  AppearancePreferences.swift
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

import AppKit
import Bookmarks
import BrowserServicesKit
import Common
import FeatureFlags
import Foundation
import NewTabPage
import PixelKit
import os.log

protocol AppearancePreferencesPersistor {
    var showFullURL: Bool { get set }
    var currentThemeName: String { get set }
    var favoritesDisplayMode: String? { get set }
    var isFavoriteVisible: Bool { get set }
    var isContinueSetUpVisible: Bool { get set }
    var continueSetUpCardsLastDemonstrated: Date? { get set }
    var continueSetUpCardsNumberOfDaysDemonstrated: Int { get set }
    var continueSetUpCardsClosed: Bool { get set }
    var isRecentActivityVisible: Bool { get set }
    var isPrivacyStatsVisible: Bool { get set }
    var isSearchBarVisible: Bool { get set }
    var showBookmarksBar: Bool { get set }
    var bookmarksBarAppearance: BookmarksBarAppearance { get set }
    var homeButtonPosition: HomeButtonPosition { get set }
    var homePageCustomBackground: String? { get set }
    var centerAlignedBookmarksBar: Bool { get set }
    var showTabsAndBookmarksBarOnFullScreen: Bool { get set }
}

struct AppearancePreferencesUserDefaultsPersistor: AppearancePreferencesPersistor {
    @UserDefaultsWrapper(key: .showFullURL, defaultValue: false)
    var showFullURL: Bool

    @UserDefaultsWrapper(key: .currentThemeName, defaultValue: ThemeName.systemDefault.rawValue)
    var currentThemeName: String

    @UserDefaultsWrapper(key: .favoritesDisplayMode, defaultValue: FavoritesDisplayMode.displayNative(.desktop).description)
    var favoritesDisplayMode: String?

    @UserDefaultsWrapper(key: .homePageIsFavoriteVisible, defaultValue: true)
    var isFavoriteVisible: Bool

    @UserDefaultsWrapper(key: .homePageIsContinueSetupVisible, defaultValue: true)
    var isContinueSetUpVisible: Bool

    @UserDefaultsWrapper(key: .continueSetUpCardsLastDemonstrated)
    var continueSetUpCardsLastDemonstrated: Date?

    @UserDefaultsWrapper(key: .continueSetUpCardsNumberOfDaysDemonstrated, defaultValue: 0)
    var continueSetUpCardsNumberOfDaysDemonstrated: Int

    @UserDefaultsWrapper(key: .continueSetUpCardsClosed, defaultValue: false)
    var continueSetUpCardsClosed: Bool

    @UserDefaultsWrapper(key: .homePageIsRecentActivityVisible, defaultValue: true)
    var isRecentActivityVisible: Bool

    @UserDefaultsWrapper(key: .homePageIsPrivacyStatsVisible, defaultValue: true)
    var isPrivacyStatsVisible: Bool

    @UserDefaultsWrapper(key: .homePageIsSearchBarVisible, defaultValue: true)
    var isSearchBarVisible: Bool

    @UserDefaultsWrapper(key: .showBookmarksBar, defaultValue: false)
    var showBookmarksBar: Bool

    @UserDefaultsWrapper(key: .bookmarksBarAppearance, defaultValue: BookmarksBarAppearance.alwaysOn.rawValue)
    private var bookmarksBarValue: String
    var bookmarksBarAppearance: BookmarksBarAppearance {
        get {
            return BookmarksBarAppearance(rawValue: bookmarksBarValue) ?? .alwaysOn
        }

        set {
            bookmarksBarValue = newValue.rawValue
        }
    }

    @UserDefaultsWrapper(key: .homeButtonPosition, defaultValue: .right)
    var homeButtonPosition: HomeButtonPosition {
        didSet {
            if homeButtonPosition != .hidden {
                PixelExperiment.fireOnboardingHomeButtonEnabledPixel()
            }
        }
    }

    @UserDefaultsWrapper(key: .homePageCustomBackground, defaultValue: nil)
    var homePageCustomBackground: String?

    @UserDefaultsWrapper(key: .centerAlignedBookmarksBar, defaultValue: true)
    var centerAlignedBookmarksBar: Bool

    @UserDefaultsWrapper(key: .showTabsAndBookmarksBarOnFullScreen, defaultValue: true)
    var showTabsAndBookmarksBarOnFullScreen: Bool
}

protocol HomePageNavigator {
    func openNewTabPageBackgroundCustomizationSettings()
}

final class DefaultHomePageNavigator: HomePageNavigator {
    func openNewTabPageBackgroundCustomizationSettings() {
        Task { @MainActor in
            WindowControllersManager.shared.showTab(with: .newtab)
            try? await Task.sleep(interval: 0.2)
            if let window = WindowControllersManager.shared.lastKeyMainWindowController {
                let homePageViewController = window.mainViewController.browserTabViewController.homePageViewController
                homePageViewController?.settingsVisibilityModel.isSettingsVisible = true

                if NSApp.delegateTyped.featureFlagger.isFeatureOn(.htmlNewTabPage) {
                    let newTabPageViewModel = window.mainViewController.browserTabViewController.newTabPageWebViewModel
                    NSApp.delegateTyped.homePageSettingsModel.customizerOpener.openSettings(for: newTabPageViewModel.webView)
                }
            }
        }
    }
}

enum HomeButtonPosition: String, CaseIterable {
    case hidden
    case left
    case right
}

enum ThemeName: String, Equatable, CaseIterable {
    case light
    case dark
    case systemDefault

    var appearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .light:
            return UserText.themeLight
        case .dark:
            return UserText.themeDark
        case .systemDefault:
            return UserText.themeSystem
        }
    }

    var imageName: String {
        switch self {
        case .light:
            return "LightModePreview"
        case .dark:
            return "DarkModePreview"
        case .systemDefault:
            return "SystemDefaultPreview"
        }
    }
}

extension FavoritesDisplayMode: @retroactive LosslessStringConvertible {
    static let `default` = FavoritesDisplayMode.displayNative(.desktop)

    public init?(_ description: String) {
        switch description {
        case FavoritesDisplayMode.displayNative(.desktop).description:
            self = .displayNative(.desktop)
        case FavoritesDisplayMode.displayUnified(native: .desktop).description:
            self = .displayUnified(native: .desktop)
        default:
            return nil
        }
    }
}

final class AppearancePreferences: ObservableObject {

    struct Notifications {
        static let showBookmarksBarSettingChanged = NSNotification.Name("ShowBookmarksBarSettingChanged")
        static let bookmarksBarSettingAppearanceChanged = NSNotification.Name("BookmarksBarSettingAppearanceChanged")
        static let bookmarksBarAlignmentChanged = NSNotification.Name("BookmarksBarAlignmentChanged")
        static let showTabsAndBookmarksBarOnFullScreenChanged = NSNotification.Name("ShowTabsAndBookmarksBarOnFullScreenChanged")
    }

    struct Constants {
        static let bookmarksBarAlignmentChangedIsCenterAlignedParameter = "isCenterAligned"
        static let showTabsAndBookmarksBarOnFullScreenParameter = "showTabsAndBookmarksBarOnFullScreen"
        static let dismissNextStepsCardsAfterDays = 9
    }

    static let shared = AppearancePreferences()

    @Published var currentThemeName: ThemeName {
        didSet {
            persistor.currentThemeName = currentThemeName.rawValue
            updateUserInterfaceStyle()
        }
    }

    @Published var showFullURL: Bool {
        didSet {
            persistor.showFullURL = showFullURL
        }
    }

    @Published var favoritesDisplayMode: FavoritesDisplayMode {
        didSet {
            persistor.favoritesDisplayMode = favoritesDisplayMode.description
        }
    }

    @Published var isFavoriteVisible: Bool {
        didSet {
            persistor.isFavoriteVisible = isFavoriteVisible
            if !isFavoriteVisible {
                PixelKit.fire(NewTabPagePixel.favoriteSectionHidden, frequency: .dailyAndStandard)
            }
        }
    }

    @Published var isContinueSetUpCardsViewOutdated: Bool

    @Published var continueSetUpCardsClosed: Bool {
        didSet {
            persistor.continueSetUpCardsClosed = continueSetUpCardsClosed
        }
    }

    var isContinueSetUpCardsVisibilityControlAvailable: Bool {
        // HTML NTP doesn't allow for hiding Next Steps Cards section
        !featureFlagger().isFeatureOn(.htmlNewTabPage)
    }

    var isContinueSetUpVisible: Bool {
        get {
            return persistor.isContinueSetUpVisible && !persistor.continueSetUpCardsClosed && !isContinueSetUpCardsViewOutdated
        }
        set {
            persistor.isContinueSetUpVisible = newValue
            // Temporary Pixel
            if !isContinueSetUpVisible {
                PixelKit.fire(GeneralPixel.continueSetUpSectionHidden)
            }
            self.objectWillChange.send()
        }
    }

    func continueSetUpCardsViewDidAppear() {
        guard isContinueSetUpVisible, !isContinueSetUpCardsViewOutdated else { return }

        if let continueSetUpCardsLastDemonstrated = persistor.continueSetUpCardsLastDemonstrated {
            // how many days has passed since last Continue Setup demonstration
            let daysSinceLastDemonstration = Calendar.current.dateComponents([.day], from: continueSetUpCardsLastDemonstrated, to: dateTimeProvider()).day!
            if daysSinceLastDemonstration > 0 {
                persistor.continueSetUpCardsLastDemonstrated = Date()
                persistor.continueSetUpCardsNumberOfDaysDemonstrated += 1

                if persistor.continueSetUpCardsNumberOfDaysDemonstrated >= Constants.dismissNextStepsCardsAfterDays {
                    self.isContinueSetUpCardsViewOutdated = true
                }
            }

        } else if persistor.continueSetUpCardsLastDemonstrated == nil {
            persistor.continueSetUpCardsLastDemonstrated = Date()
        }
    }

    @Published var isRecentActivityVisible: Bool {
        didSet {
            persistor.isRecentActivityVisible = isRecentActivityVisible
            if !isRecentActivityVisible {
                PixelKit.fire(NewTabPagePixel.recentActivitySectionHidden, frequency: .dailyAndStandard)
            }
        }
    }

    @Published var isPrivacyStatsVisible: Bool {
        didSet {
            persistor.isPrivacyStatsVisible = isPrivacyStatsVisible
            if !isPrivacyStatsVisible {
                PixelKit.fire(NewTabPagePixel.blockedTrackingAttemptsSectionHidden, frequency: .dailyAndStandard)
            }
        }
    }

    @Published var isSearchBarVisible: Bool {
        didSet {
            persistor.isSearchBarVisible = isSearchBarVisible
        }
    }

    @Published var showBookmarksBar: Bool {
        didSet {
            persistor.showBookmarksBar = showBookmarksBar
            NotificationCenter.default.post(name: Notifications.showBookmarksBarSettingChanged, object: nil)
            if showBookmarksBar {
                PixelExperiment.fireOnboardingBookmarksBarShownPixel()
            }
        }
    }
    @Published var bookmarksBarAppearance: BookmarksBarAppearance {
        didSet {
            persistor.bookmarksBarAppearance = bookmarksBarAppearance
            NotificationCenter.default.post(name: Notifications.bookmarksBarSettingAppearanceChanged, object: nil)
        }
    }

    @Published var homeButtonPosition: HomeButtonPosition {
        didSet {
            persistor.homeButtonPosition = homeButtonPosition
        }
    }

    @Published var homePageCustomBackground: CustomBackground? {
        didSet {
            persistor.homePageCustomBackground = homePageCustomBackground?.description
        }
    }

    @Published var centerAlignedBookmarksBarBool: Bool {
        didSet {
            persistor.centerAlignedBookmarksBar = centerAlignedBookmarksBarBool
            NotificationCenter.default.post(name: Notifications.bookmarksBarAlignmentChanged,
                                            object: nil,
                                            userInfo: [Constants.bookmarksBarAlignmentChangedIsCenterAlignedParameter: centerAlignedBookmarksBarBool])
        }
    }

    @Published var showTabsAndBookmarksBarOnFullScreen: Bool {
        didSet {
            persistor.showTabsAndBookmarksBarOnFullScreen = showTabsAndBookmarksBarOnFullScreen
            NotificationCenter.default.post(name: Notifications.showTabsAndBookmarksBarOnFullScreenChanged,
                                            object: nil,
                                            userInfo: [Constants.showTabsAndBookmarksBarOnFullScreenParameter: showTabsAndBookmarksBarOnFullScreen])
        }
    }

    var isContinueSetUpAvailable: Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion

        let privacyConfig = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig
        return privacyConfig.isEnabled(featureKey: .newTabContinueSetUp) && osVersion.majorVersion >= 12
    }

    var isRecentActivityAvailable: Bool {
        newTabPageSectionsAvailabilityProvider.isRecentActivityAvailable
    }

    var isPrivacyStatsAvailable: Bool {
        newTabPageSectionsAvailabilityProvider.isPrivacyStatsAvailable
    }

    func updateUserInterfaceStyle() {
        NSApp.appearance = currentThemeName.appearance
    }

    func openNewTabPageBackgroundCustomizationSettings() {
        homePageNavigator.openNewTabPageBackgroundCustomizationSettings()
    }

    init(
        persistor: AppearancePreferencesPersistor = AppearancePreferencesUserDefaultsPersistor(),
        homePageNavigator: HomePageNavigator = DefaultHomePageNavigator(),
        newTabPageSectionsAvailabilityProvider: NewTabPageSectionsAvailabilityProviding = NewTabPageModeDecider(),
        featureFlagger: @autoclosure @escaping () -> FeatureFlagger = NSApp.delegateTyped.featureFlagger,
        dateTimeProvider: @escaping () -> Date = Date.init
    ) {
        self.persistor = persistor
        self.homePageNavigator = homePageNavigator
        self.dateTimeProvider = dateTimeProvider
        self.isContinueSetUpCardsViewOutdated = persistor.continueSetUpCardsNumberOfDaysDemonstrated >= Constants.dismissNextStepsCardsAfterDays
        self.featureFlagger = featureFlagger
        self.newTabPageSectionsAvailabilityProvider = newTabPageSectionsAvailabilityProvider
        self.continueSetUpCardsClosed = persistor.continueSetUpCardsClosed
        currentThemeName = .init(rawValue: persistor.currentThemeName) ?? .systemDefault
        showFullURL = persistor.showFullURL
        favoritesDisplayMode = persistor.favoritesDisplayMode.flatMap(FavoritesDisplayMode.init) ?? .default
        isFavoriteVisible = persistor.isFavoriteVisible
        isRecentActivityVisible = persistor.isRecentActivityVisible
        isPrivacyStatsVisible = persistor.isPrivacyStatsVisible
        isSearchBarVisible = persistor.isSearchBarVisible
        showBookmarksBar = persistor.showBookmarksBar
        bookmarksBarAppearance = persistor.bookmarksBarAppearance
        homeButtonPosition = persistor.homeButtonPosition
        homePageCustomBackground = persistor.homePageCustomBackground.flatMap(CustomBackground.init)
        centerAlignedBookmarksBarBool = persistor.centerAlignedBookmarksBar
        showTabsAndBookmarksBarOnFullScreen = persistor.showTabsAndBookmarksBarOnFullScreen
    }

    private var persistor: AppearancePreferencesPersistor
    private var homePageNavigator: HomePageNavigator
    private let newTabPageSectionsAvailabilityProvider: NewTabPageSectionsAvailabilityProviding
    private let featureFlagger: () -> FeatureFlagger
    private let dateTimeProvider: () -> Date

    private func requestSync() {
        Task { @MainActor in
            guard let syncService = NSApp.delegateTyped.syncService else { return }
            Logger.sync.debug("Requesting sync if enabled")
            syncService.scheduler.notifyDataChanged()
        }
    }
}
