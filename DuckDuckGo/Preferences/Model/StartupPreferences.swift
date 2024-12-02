//
//  StartupPreferences.swift
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
import Combine

protocol StartupPreferencesPersistor {
    var restorePreviousSession: Bool { get set }
    var launchToCustomHomePage: Bool { get set }
    var customHomePageURL: String { get set }
}

struct StartupPreferencesUserDefaultsPersistor: StartupPreferencesPersistor {
    @UserDefaultsWrapper(key: .restorePreviousSession, defaultValue: false)
    var restorePreviousSession: Bool

    @UserDefaultsWrapper(key: .launchToCustomHomePage, defaultValue: false)
    var launchToCustomHomePage: Bool

    @UserDefaultsWrapper(key: .customHomePageURL, defaultValue: URL.duckDuckGo.absoluteString)
    var customHomePageURL: String

}

final class StartupPreferences: ObservableObject, PreferencesTabOpening {

    static let shared = StartupPreferences()
    private let pinningManager: LocalPinningManager
    private var appearancePreferences: AppearancePreferences
    private var persistor: StartupPreferencesPersistor
    private var pinnedViewsNotificationCancellable: AnyCancellable?
    private var dataClearingPreferences: DataClearingPreferences
    private var dataClearingPreferencesNotificationCancellable: AnyCancellable?

    init(pinningManager: LocalPinningManager = .shared,
         appearancePreferences: AppearancePreferences = .shared,
         persistor: StartupPreferencesPersistor = StartupPreferencesUserDefaultsPersistor(),
         dataClearingPreferences: DataClearingPreferences = .shared) {
        self.pinningManager = pinningManager
        self.appearancePreferences = appearancePreferences
        self.persistor = persistor
        self.dataClearingPreferences = dataClearingPreferences
        restorePreviousSession = persistor.restorePreviousSession
        launchToCustomHomePage = persistor.launchToCustomHomePage
        customHomePageURL = persistor.customHomePageURL
        updateHomeButtonState()
        listenToPinningManagerNotifications()
        listenToDataClearingPreferencesNotifications()
        checkDataClearingStatus()
    }

    @Published var restorePreviousSession: Bool {
        didSet {
            persistor.restorePreviousSession = restorePreviousSession
            if restorePreviousSession {
                PixelExperiment.fireOnboardingSessionRestoreEnabledPixel()
                PixelExperiment.fireOnboardingSessionRestoreEnabled5to7Pixel()
            }
        }
    }

    @Published var launchToCustomHomePage: Bool {
        didSet {
            persistor.launchToCustomHomePage = launchToCustomHomePage
        }
    }

    @Published var customHomePageURL: String {
        didSet {
            guard let urlWithScheme = urlWithScheme(customHomePageURL) else {
                return
            }
            if customHomePageURL != urlWithScheme {
                customHomePageURL = urlWithScheme
            }
            persistor.customHomePageURL = customHomePageURL
        }
    }

    @Published var homeButtonPosition: HomeButtonPosition = .hidden

    var formattedCustomHomePageURL: String {
        let trimmedURL = customHomePageURL.trimmingWhitespace()
        guard let url = URL(trimmedAddressBarString: trimmedURL) else {
            return URL.duckDuckGo.absoluteString
        }
        return url.absoluteString
    }

    var friendlyURL: String {
        var friendlyURL = customHomePageURL
        if friendlyURL.count > 30 {
            let index = friendlyURL.index(friendlyURL.startIndex, offsetBy: 27)
            friendlyURL = String(friendlyURL[..<index]) + "..."
        }
        return friendlyURL
    }

    func isValidURL(_ text: String) -> Bool {
        guard let url = text.url else { return false }
        return !text.isEmpty && url.isValid
    }

    func updateHomeButton() {
        appearancePreferences.homeButtonPosition = homeButtonPosition
        if homeButtonPosition != .hidden {
            pinningManager.unpin(.homeButton)
            pinningManager.pin(.homeButton)
        } else {
            pinningManager.unpin(.homeButton)
        }
    }

    private func updateHomeButtonState() {
        homeButtonPosition = pinningManager.isPinned(.homeButton) ? appearancePreferences.homeButtonPosition : .hidden
    }

    private func listenToPinningManagerNotifications() {
        pinnedViewsNotificationCancellable = NotificationCenter.default.publisher(for: .PinnedViewsChanged).sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.updateHomeButtonState()
        }
    }

    private func checkDataClearingStatus() {
        if dataClearingPreferences.isAutoClearEnabled {
            restorePreviousSession = false
        }
    }

    private func listenToDataClearingPreferencesNotifications() {
        dataClearingPreferencesNotificationCancellable = NotificationCenter.default.publisher(for: .autoClearDidChange).sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.checkDataClearingStatus()
        }
    }

    private func urlWithScheme(_ urlString: String) -> String? {
        guard var urlWithScheme = urlString.url else {
            return nil
        }
        // Force 'https' if 'http' not explicitly set by user
        if urlWithScheme.isHttp && !urlString.hasPrefix(URL.NavigationalScheme.http.separated()) {
            urlWithScheme = urlWithScheme.toHttps() ?? urlWithScheme
        }
        return urlWithScheme.toString(decodePunycode: true, dropScheme: false, dropTrailingSlash: true)
    }

}
