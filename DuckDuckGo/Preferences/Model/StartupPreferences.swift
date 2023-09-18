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

    init(persistor: StartupPreferencesPersistor = StartupPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        restorePreviousSession = persistor.restorePreviousSession
        launchToCustomHomePage = persistor.launchToCustomHomePage
        customHomePageURL = persistor.customHomePageURL
    }

    private var persistor: StartupPreferencesPersistor

    @MainActor
    func presentHomePageDialog() {
        let fireproofDomainsWindowController = FireproofDomainsViewController.create().wrappedInWindowController()

        guard let fireproofDomainsWindow = fireproofDomainsWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Privacy Preferences: Failed to present FireproofDomainsViewController")
            return
        }
        parentWindowController.window?.beginSheet(fireproofDomainsWindow)
    }

}

extension StartupPreferences {
    var customHomePageFormatted: String {
        var formattedURL = customHomePageURL.replacingOccurrences(of: "http://", with: "")
        formattedURL = formattedURL.replacingOccurrences(of: "https://", with: "")

        if formattedURL.count > 100 {
            let index = formattedURL.index(formattedURL.startIndex, offsetBy: 97)
            formattedURL = String(formattedURL[..<index]) + "..."
        }

        return formattedURL
    }
}
