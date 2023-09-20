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

protocol StartupPreferencesPersistor {
    var restorePreviousSession: Bool { get set }
    var launchToCustomHomePage: Bool { get set }
    var customHomePageURL: String { get set }
}

struct StartupPreferencesUserDefaultsPersistor: StartupPreferencesPersistor {

    static let defaultURL = "https://duckduckgo.com"

    @UserDefaultsWrapper(key: .restorePreviousSession, defaultValue: false)
    var restorePreviousSession: Bool

    @UserDefaultsWrapper(key: .launchToCustomHomePage, defaultValue: false)
    var launchToCustomHomePage: Bool

    @UserDefaultsWrapper(key: .customHomePageURL, defaultValue: Self.defaultURL)
    var customHomePageURL: String

}

final class StartupPreferences: ObservableObject {

    static let shared = StartupPreferences()

    @Published var restorePreviousSession: Bool {
        didSet {
            persistor.restorePreviousSession = restorePreviousSession
        }
    }

    @Published var launchToCustomHomePage: Bool {
        didSet {
            persistor.launchToCustomHomePage = launchToCustomHomePage
        }
    }

    @Published var customHomePageURL: String {
        didSet {
            persistor.customHomePageURL = customHomePageURL
        }
    }

    var formattedcustomHomePageURL: String {
        let trimmedURL = customHomePageURL.trimmingWhitespace()
        guard let url = URL(trimmedAddressBarString: trimmedURL) else {
            return StartupPreferencesUserDefaultsPersistor.defaultURL
        }
        return url.absoluteString
    }

    var friendlyURL: String {
        let regexPattern = "https?://"
        var friendlyURL = customHomePageURL.replacingOccurrences(of: regexPattern, with: "", options: .regularExpression)
        if friendlyURL.count > 30 {
            let index = friendlyURL.index(friendlyURL.startIndex, offsetBy: 27)
            friendlyURL = String(friendlyURL[..<index]) + "..."
        }
        return friendlyURL
    }

    init(persistor: StartupPreferencesPersistor = StartupPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        restorePreviousSession = persistor.restorePreviousSession
        launchToCustomHomePage = persistor.launchToCustomHomePage
        customHomePageURL = persistor.customHomePageURL
    }

    private var persistor: StartupPreferencesPersistor

    func isValidURL(_ text: String) -> Bool {
        guard let url = text.url else { return false }
        return !text.isEmpty && url.isValid
    }

}
