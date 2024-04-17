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

#if SUBSCRIPTION
import Subscription
#endif

extension Tab {

    enum Content: Equatable {
        case newtab
        case url(URL, credential: URLCredential? = nil, source: URLSource)
        case settings(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none
        case dataBrokerProtection
        case subscription(URL)
        case identityTheftRestoration(URL)
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
            case .userEntered:
                    .custom(.userEnteredUrl)
            case .pendingStateRestoration:
                    .sessionRestoration
            case .loadedByStateRestoration, .appOpenUrl, .historyEntry, .bookmark, .ui, .link, .webViewUpdated:
                    .custom(.tabContentUpdate)
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
            case .userEntered, .bookmark, .ui, .link, .appOpenUrl, .webViewUpdated:
                    .useProtocolCachePolicy
            }
        }

    }
}
extension TabContent {

    // swiftlint:disable:next cyclomatic_complexity
    static func contentFromURL(_ url: URL?, source: URLSource) -> TabContent {
        switch url {
        case URL.newtab, URL.Invalid.aboutNewtab, URL.Invalid.duckHome:
            return .newtab
        case URL.welcome, URL.Invalid.aboutWelcome:
            return .onboarding
        case URL.settings, URL.Invalid.aboutPreferences, URL.Invalid.aboutConfig, URL.Invalid.aboutSettings, URL.Invalid.duckConfig, URL.Invalid.duckPreferences:
            return .anySettingsPane
        case URL.bookmarks, URL.Invalid.aboutBookmarks:
            return .bookmarks
        case URL.dataBrokerProtection:
            return .dataBrokerProtection
        case URL.Invalid.aboutHome:
            guard let customURL = URL(string: StartupPreferences.shared.formattedCustomHomePageURL) else {
                return .newtab
            }
            return .url(customURL, source: source)
        default: break
        }

#if SUBSCRIPTION
        if let url {
            if url.isChild(of: URL.subscriptionBaseURL) {
                if SubscriptionPurchaseEnvironment.currentServiceEnvironment == .staging, url.getParameter(named: "environment") == nil {
                    return .subscription(url.appendingParameter(name: "environment", value: "staging"))
                }
                return .subscription(url)
            } else if url.isChild(of: URL.identityTheftRestoration) {
                return .identityTheftRestoration(url)
            }
        }
#endif

        if let settingsPane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
            return .settings(pane: settingsPane)
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
        case .settings, .bookmarks, .dataBrokerProtection, .subscription, .identityTheftRestoration:
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
        case (.dataBrokerProtection, .dataBrokerProtection):
            return true
        case (.subscription, .subscription):
            return true
        case (.identityTheftRestoration, .identityTheftRestoration):
            return true
        default:
            return false
        }
    }

    var title: String? {
        switch self {
        case .url, .newtab, .none: return nil
        case .settings: return UserText.tabPreferencesTitle
        case .bookmarks: return UserText.tabBookmarksTitle
        case .onboarding: return UserText.tabOnboardingTitle
        case .dataBrokerProtection: return UserText.tabDataBrokerProtectionTitle
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
        case .onboarding:
            return .welcome
        case .dataBrokerProtection:
            return .dataBrokerProtection
        case .subscription(let url), .identityTheftRestoration(let url):
            return url
        case .none:
            return nil
        }
    }

    var source: URLSource {
        switch self {
        case .url(_, _, source: let source):
            return source
        case .newtab, .settings, .bookmarks, .onboarding, .dataBrokerProtection,
                .subscription, .identityTheftRestoration, .none:
            return .ui
        }
    }

    var isUrl: Bool {
        switch self {
        case .url, .subscription, .identityTheftRestoration:
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

    var canBeDuplicated: Bool {
        switch self {
        case .settings, .subscription, .identityTheftRestoration, .dataBrokerProtection:
            return false
        default:
            return true
        }
    }

    var canBePinned: Bool {
        switch self {
        case .subscription, .identityTheftRestoration, .dataBrokerProtection:
            return false
        default:
            return isUrl
        }
    }

    var canBeBookmarked: Bool {
        switch self {
        case .subscription, .identityTheftRestoration, .dataBrokerProtection:
            return false
        default:
            return isUrl
        }
    }

}
