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

import Foundation
import AppKit
import Bookmarks
import Common

protocol AppearancePreferencesPersistor {
    var showFullURL: Bool { get set }
    var currentThemeName: String { get set }
    var favoritesDisplayMode: String? { get set }
    var isFavoriteVisible: Bool { get set }
    var isContinueSetUpVisible: Bool { get set }
    var isRecentActivityVisible: Bool { get set }
    var showBookmarksBar: Bool { get set }
    var bookmarksBarAppearance: BookmarksBarAppearance { get set }
    var homeButtonPosition: HomeButtonPosition { get set }
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

    @UserDefaultsWrapper(key: .homePageIsRecentActivityVisible, defaultValue: true)
    var isRecentActivityVisible: Bool

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
    var homeButtonPosition: HomeButtonPosition
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

extension FavoritesDisplayMode: LosslessStringConvertible {
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
            // Temporary Pixel
            if !isFavoriteVisible {
                Pixel.fire(.favoriteSectionHidden)
            }
        }
    }

    @Published var isContinueSetUpVisible: Bool {
        didSet {
            persistor.isContinueSetUpVisible = isContinueSetUpVisible
            // Temporary Pixel
            if !isContinueSetUpVisible {
                Pixel.fire(.continueSetUpSectionHidden)
            }
        }
    }

    @Published var isRecentActivityVisible: Bool {
        didSet {
            persistor.isRecentActivityVisible = isRecentActivityVisible
            // Temporary Pixel
            if !isRecentActivityVisible {
                Pixel.fire(.recentActivitySectionHidden)
            }
        }
    }

    @Published var showBookmarksBar: Bool {
        didSet {
            persistor.showBookmarksBar = showBookmarksBar
            NotificationCenter.default.post(name: Notifications.showBookmarksBarSettingChanged, object: nil)
        }
    }
    @Published var bookmarksBarAppearance: BookmarksBarAppearance {
        didSet {
            persistor.bookmarksBarAppearance = bookmarksBarAppearance
        }
    }

    @Published var homeButtonPosition: HomeButtonPosition {
        didSet {
            persistor.homeButtonPosition = homeButtonPosition
        }
    }

    var isContinueSetUpAvailable: Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion

        let privacyConfig = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig
        return privacyConfig.isEnabled(featureKey: .newTabContinueSetUp) && osVersion.majorVersion >= 12
    }

    func updateUserInterfaceStyle() {
        NSApp.appearance = currentThemeName.appearance
    }

    init(persistor: AppearancePreferencesPersistor = AppearancePreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        currentThemeName = .init(rawValue: persistor.currentThemeName) ?? .systemDefault
        showFullURL = persistor.showFullURL
        favoritesDisplayMode = persistor.favoritesDisplayMode.flatMap(FavoritesDisplayMode.init) ?? .default
        isFavoriteVisible = persistor.isFavoriteVisible
        isRecentActivityVisible = persistor.isRecentActivityVisible
        isContinueSetUpVisible = persistor.isContinueSetUpVisible
        showBookmarksBar = persistor.showBookmarksBar
        bookmarksBarAppearance = persistor.bookmarksBarAppearance
        homeButtonPosition = persistor.homeButtonPosition
    }

    private var persistor: AppearancePreferencesPersistor

    private func requestSync() {
        Task { @MainActor in
            guard let syncService = (NSApp.delegate as? AppDelegate)?.syncService else {
                return
            }
            os_log(.debug, log: OSLog.sync, "Requesting sync if enabled")
            syncService.scheduler.notifyDataChanged()
        }
    }
}
