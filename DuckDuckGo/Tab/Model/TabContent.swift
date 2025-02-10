//
//  TabContent.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Navigation
import Subscription

extension Tab {

    enum Content: Equatable {
        case newtab
        case url(URL, credential: URLCredential? = nil, source: URLSource)
        case settings(pane: PreferencePaneIdentifier?)
        case bookmarks
        case history
        case onboardingDeprecated
        case onboarding
        case none
        case dataBrokerProtection
        case subscription(URL)
        case identityTheftRestoration(URL)
        case releaseNotes
        case webExtensionUrl(URL)
    }
    typealias TabContent = Tab.Content

}
typealias TabContent = Tab.Content

extension TabContent {

    enum URLSource: Equatable {
        case pendingStateRestoration
        case loadedByStateRestoration
        case userEntered(String, downloadRequested: Bool = false)
        case historyEntry
        case bookmark
        case ui
        case link
        case appOpenUrl
        case reload
        case switchToOpenTab

        case webViewUpdated

        var userEnteredValue: String? {
            if case .userEntered(let userEnteredValue, _) = self {
                userEnteredValue
            } else {
                nil
            }
        }

        var isUserEnteredUrl: Bool {
            userEnteredValue != nil
        }

        var navigationType: NavigationType {
            switch self {
            case .userEntered(_, downloadRequested: true):
                .custom(.userRequestedPageDownload)
            case .userEntered, .switchToOpenTab /* fallback */:
                .custom(.userEnteredUrl)
            case .pendingStateRestoration:
                .sessionRestoration
            case .loadedByStateRestoration:
                .custom(.loadedByStateRestoration)
            case .appOpenUrl:
                .custom(.appOpenUrl)
            case .historyEntry:
                .custom(.historyEntry)
            case .bookmark:
                .custom(.bookmark)
            case .ui:
                .custom(.ui)
            case .link:
                .custom(.link)
            case .webViewUpdated:
                .custom(.webViewUpdated)
            case .reload:
                .reload
            }
        }

        var cachePolicy: URLRequest.CachePolicy {
            switch self {
            case .pendingStateRestoration, .historyEntry:
                .returnCacheDataElseLoad
            case .reload, .loadedByStateRestoration:
                .reloadIgnoringCacheData
            case .userEntered, .bookmark, .ui, .link, .appOpenUrl, .webViewUpdated, .switchToOpenTab:
                .useProtocolCachePolicy
            }
        }

    }
}
extension TabContent {

    static func contentFromURL(_ url: URL?, source: URLSource) -> TabContent {
        switch url {
        case URL.newtab, URL.Invalid.aboutNewtab, URL.Invalid.duckHome:
            return .newtab
        case URL.welcome, URL.Invalid.aboutWelcome:
            return .onboardingDeprecated
        case URL.onboarding:
            return .onboarding
        case URL.settings, URL.Invalid.aboutPreferences, URL.Invalid.aboutConfig, URL.Invalid.aboutSettings, URL.Invalid.duckConfig, URL.Invalid.duckPreferences:
            return .anySettingsPane
        case URL.bookmarks, URL.Invalid.aboutBookmarks:
            return .bookmarks
        case URL.history:
            return .history
        case URL.dataBrokerProtection:
            return .dataBrokerProtection
        case URL.releaseNotes:
            return .releaseNotes
        case URL.Invalid.aboutHome:
            guard let customURL = URL(string: StartupPreferences.shared.formattedCustomHomePageURL) else {
                return .newtab
            }
            return .url(customURL, source: source)
        default: break
        }

        if let url {
            if url.isWebExtensionUrl {
                return .webExtensionUrl(url)
            }

            let subscriptionManager = Application.appDelegate.subscriptionManager
            let environment = subscriptionManager.currentEnvironment.serviceEnvironment
            let subscriptionBaseURL = subscriptionManager.url(for: .baseURL)
            let identityTheftRestorationURL = subscriptionManager.url(for: .identityTheftRestoration)
            if url.isChild(of: subscriptionBaseURL) {
                if environment == .staging, url.getParameter(named: "environment") == nil {
                    return .subscription(url.appendingParameter(name: "environment", value: "staging"))
                }
                return .subscription(url)
            } else if url.isChild(of: identityTheftRestorationURL) {
                return .identityTheftRestoration(url)
            }
        }

        if let settingsPane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
            return .settings(pane: settingsPane)
        } else if url?.isDuckPlayer == true, let (videoId, timestamp) = url?.youtubeVideoParams {
            return .url(.duckPlayer(videoId, timestamp: timestamp), credential: nil, source: source)
        } else if let url, let credential = url.basicAuthCredential {
            // when navigating to a URL with basic auth username/password, cache it and redirect to a trimmed URL
            return .url(url.removingBasicAuthCredential(), credential: credential, source: source)
        } else {
            return .url(url ?? .blankPage, source: source)
        }
    }

    static var displayableTabTypes: [TabContent] {
        // Add new displayable types here
        let displayableTypes = [TabContent.anySettingsPane, .bookmarks]

        return displayableTypes.sorted { first, second in
            guard let firstTitle = first.title, let secondTitle = second.title else {
                return true // Arbitrary sort order, only non-standard tabs are displayable.
            }
            return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
        }
    }

    /// Convenience accessor for `.preferences` Tab Content with no particular pane selected,
    /// i.e. the currently selected pane is decided internally by `PreferencesViewController`.
    static let anySettingsPane: Self = .settings(pane: nil)

    var isDisplayable: Bool {
        switch self {
        case .settings, .bookmarks, .history, .dataBrokerProtection, .subscription, .identityTheftRestoration, .releaseNotes:
            return true
        default:
            return false
        }
    }

    func matchesDisplayableTab(_ other: TabContent) -> Bool {
        switch (self, other) {
        case (.settings, .settings):
            return true
        case (.bookmarks, .bookmarks):
            return true
        case (.history, .history):
            return true
        case (.dataBrokerProtection, .dataBrokerProtection):
            return true
        case (.subscription, .subscription):
            return true
        case (.identityTheftRestoration, .identityTheftRestoration):
            return true
        case (.releaseNotes, .releaseNotes):
            return true
        default:
            return false
        }
    }

    var title: String? {
        switch self {
        case .url, .newtab, .onboarding, .none, .webExtensionUrl: return nil
        case .settings: return UserText.tabPreferencesTitle
        case .bookmarks: return UserText.tabBookmarksTitle
        case .history: return UserText.mainMenuHistory
        case .onboardingDeprecated: return UserText.tabOnboardingTitle
        case .dataBrokerProtection: return UserText.tabDataBrokerProtectionTitle
        case .releaseNotes: return UserText.releaseNotesTitle
        case .subscription, .identityTheftRestoration: return nil
        }
    }

    // !!! don‘t add `url` property to avoid ambiguity with the `.url` enum case
    // use `userEditableUrl` or `urlForWebView` instead.

    /// user-editable URL displayed in the address bar
    var userEditableUrl: URL? {
        let url = urlForWebView
        if let url, url.isDuckPlayer,
           let (videoID, timestamp) = url.youtubeVideoParams {
            return .duckPlayer(videoID, timestamp: timestamp)
        }
        return url
    }

    /// `real` URL loaded in the web view
    var urlForWebView: URL? {
        switch self {
        case .url(let url, credential: _, source: _):
            return url
        case .newtab:
            return .newtab
        case .settings(pane: .some(let pane)):
            return .settingsPane(pane)
        case .settings(pane: .none):
            return .settings
        case .bookmarks:
            return .bookmarks
        case .history:
            return .history
        case .onboardingDeprecated:
            return .welcome
        case .onboarding:
            return URL.onboarding
        case .dataBrokerProtection:
            return .dataBrokerProtection
        case .releaseNotes:
            return .releaseNotes
        case .subscription(let url), .identityTheftRestoration(let url), .webExtensionUrl(let url):
            return url
        case .none:
            return nil
        }
    }

    var source: URLSource {
        switch self {
        case .url(_, _, source: let source):
            return source
        case .newtab, .settings, .bookmarks, .history, .onboardingDeprecated, .onboarding, .releaseNotes, .dataBrokerProtection,
                .subscription, .identityTheftRestoration, .webExtensionUrl, .none:
            return .ui
        }
    }

    var isUrl: Bool {
        switch self {
        case .url, .subscription, .identityTheftRestoration, .releaseNotes:
            return true
        default:
            return false
        }
    }

    var userEnteredValue: String? {
        switch self {
        case .url(_, credential: _, source: let source):
            return source.userEnteredValue
        default:
            return nil
        }
    }

    var isUserEnteredUrl: Bool {
        userEnteredValue != nil
    }

    var isUserRequestedPageDownload: Bool {
        if case .url(_, credential: _, source: .userEntered(_, downloadRequested: true)) = self {
            return true
        } else {
            return false
        }
    }

    var displaysContentInWebView: Bool {
        isUrl
    }

    var usesExternalWebView: Bool {
        switch self {
        case .newtab, .history:
            return true
        default:
            return false
        }
    }

    var canBeDuplicated: Bool {
        switch self {
        case .settings, .subscription, .identityTheftRestoration, .dataBrokerProtection, .releaseNotes:
            return false
        default:
            return true
        }
    }

    var canBePinned: Bool {
        switch self {
        case .subscription, .identityTheftRestoration, .dataBrokerProtection, .releaseNotes:
            return false
        default:
            return isUrl
        }
    }

    var canBeBookmarked: Bool {
        switch self {
        case .newtab, .onboardingDeprecated, .onboarding, .none:
            return false
        case .url, .settings, .bookmarks, .history, .subscription, .identityTheftRestoration, .dataBrokerProtection, .releaseNotes, .webExtensionUrl:
            return true
        }
    }

}
