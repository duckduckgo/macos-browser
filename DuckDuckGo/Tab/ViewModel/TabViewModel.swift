//
//  TabViewModel.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Cocoa
import Combine
import Common
import WebKit

final class TabViewModel {

    enum Favicon {
        static let home = NSImage.homeFavicon
        static let burnerHome = NSImage.burnerTabFavicon
        static let preferences = NSImage.preferences
        static let bookmarks = NSImage.bookmarks
        static let dataBrokerProtection = NSImage.dbpIcon
        static let subscription = NSImage.subscriptionIcon
        static let identityTheftRestoration = NSImage.itrIcon
    }

    private(set) var tab: Tab
    private let appearancePreferences: AppearancePreferences
    private let accessibilityPreferences: AccessibilityPreferences
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var canGoBack: Bool = false

    @Published private(set) var canReload: Bool = false
    @Published private(set) var canBeBookmarked: Bool = false
    @Published var isLoading: Bool = false {
        willSet {
            if newValue {
                loadingStartTime = CACurrentMediaTime()
            }
        }
    }
    @Published var progress: Double = 0.0

    var isShowingErrorPage: Bool {
        tab.error != nil
    }

    @Published var autofillDataToSave: AutofillData?

    var loadingStartTime: CFTimeInterval?

    @Published private(set) var addressBarString: String = ""
    @Published private(set) var passiveAddressBarString: String = ""
    var lastAddressBarTextFieldValue: AddressBarTextField.Value?

    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage?
    var findInPage: FindInPageModel? { tab.findInPage?.model }

    @Published private(set) var usedPermissions = Permissions()
    @Published private(set) var permissionAuthorizationQuery: PermissionAuthorizationQuery?

    var canPrint: Bool {
        !isShowingErrorPage && canReload && tab.webView.canPrint
    }

    var canSaveContent: Bool {
        !isShowingErrorPage && canReload && !tab.webView.isInFullScreenMode
    }

    init(tab: Tab,
         appearancePreferences: AppearancePreferences = .shared,
         accessibilityPreferences: AccessibilityPreferences = .shared) {
        self.tab = tab
        self.appearancePreferences = appearancePreferences
        self.accessibilityPreferences = accessibilityPreferences

        subscribeToUrl()
        subscribeToCanGoBackForwardAndReload()
        subscribeToTitle()
        subscribeToFavicon()
        subscribeToTabError()
        subscribeToPermissions()
        subscribeToPreferences()
        subscribeToWebViewDidFinishNavigation()
        tab.$isLoading
            .assign(to: \.isLoading, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.$loadingProgress
            .assign(to: \.progress, onWeaklyHeld: self)
            .store(in: &cancellables)
        if case .url(_, credential: _, source: .pendingStateRestoration) = tab.content {
            updateAddressBarStrings()
        }
    }

    private func subscribeToUrl() {
        enum Event {
            case instant
            case didCommit
        }
        tab.$content
            .map { [tab] content -> AnyPublisher<Event, Never> in
                switch content {
                case .url(let url, _, source: .webViewUpdated),
                     .url(let url, _, source: .link):

                    // Update the address bar only after the tab did commit navigation to prevent Address Bar Spoofing
                    return tab.$committedURL.filter { committedURL in
                        committedURL == url
                    }.map { _ in
                        .didCommit
                    }.eraseToAnyPublisher()

                case .url(_, _, source: .userEntered(_, downloadRequested: true)):
                    // don‘t update the address bar for download navigations
                    return Empty().eraseToAnyPublisher()

                case .url(_, _, source: .pendingStateRestoration),
                     .url(_, _, source: .loadedByStateRestoration),
                     .url(_, _, source: .userEntered),
                     .url(_, _, source: .historyEntry),
                     .url(_, _, source: .bookmark),
                     .url(_, _, source: .ui),
                     .url(_, _, source: .appOpenUrl),
                     .url(_, _, source: .reload),
                     .newtab,
                     .settings,
                     .bookmarks,
                     .onboarding,
                     .none,
                     .dataBrokerProtection,
                     .subscription,
                     .identityTheftRestoration:
                    // Update the address bar instantly for built-in content types or user-initiated navigations
                    return Just( .instant ).eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .sink { [weak self] _ in
                guard let self else { return }

                updateAddressBarStrings()
                updateFavicon()
                updateCanBeBookmarked()
            }
            .store(in: &cancellables)
    }

    private func subscribeToCanGoBackForwardAndReload() {
        tab.$canGoBack
            .map { [weak tab] canGoBack in
                canGoBack || tab?.canBeClosedWithBack == true
            }
            .assign(to: \.canGoBack, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.$canGoForward
            .assign(to: \.canGoForward, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.$canReload
            .assign(to: \.canReload, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToTitle() {
        tab.$title
            .filter { [weak self] _ in
                self?.tab.isLazyLoadingInProgress == false
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    private func subscribeToFavicon() {
        tab.$favicon
            .filter { [weak self] _ in
                self?.tab.isLazyLoadingInProgress == false
            }
            .sink { [weak self] favicon in
                self?.updateFavicon(favicon)
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabError() {
        tab.$error
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateTitle()
                self?.updateFavicon()
                self?.updateCanBeBookmarked()
            }.store(in: &cancellables)
    }

    private func subscribeToPermissions() {
        tab.permissions.$permissions.assign(to: \.usedPermissions, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.permissions.$authorizationQuery.assign(to: \.permissionAuthorizationQuery, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToPreferences() {
        appearancePreferences.$showFullURL.dropFirst().sink { [weak self] newValue in
            guard let self = self, let url = self.tabURL, let host = self.tabHostURL else { return }
            self.updatePassiveAddressBarString(showURL: newValue, url: url, hostURL: host)
        }.store(in: &cancellables)
        accessibilityPreferences.$defaultPageZoom.sink { [weak self] newValue in
            guard let self = self else { return }
            self.tab.webView.defaultZoomValue = newValue
            self.tab.webView.zoomLevel = newValue
        }.store(in: &cancellables)
    }

    private func subscribeToWebViewDidFinishNavigation() {
        tab.webViewDidFinishNavigationPublisher.sink { [weak self] in
            self?.sendAnimationTrigger()
        }.store(in: &cancellables)
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = !isShowingErrorPage && (tab.content.url ?? .blankPage) != .blankPage
    }

    private var tabURL: URL? {
        return tab.content.url
    }

    private var tabHostURL: URL? {
        return tabURL?.root
    }

    private func updateAddressBarStrings() {
        guard tab.content.isUrl, let url = tabURL else {
            addressBarString = ""
            passiveAddressBarString = ""
            return
        }

        if url.isFileURL {
            addressBarString = url.absoluteString
            passiveAddressBarString = url.absoluteString
            return
        }

        if url.isDataURL {
            addressBarString = url.absoluteString
            passiveAddressBarString = "data:"
            return
        }

        if url.isBlobURL {
            let strippedUrl = url.stripUnsupportedCredentials()
            addressBarString = strippedUrl
            passiveAddressBarString = strippedUrl
            return
        }

        guard let hostURL = tabHostURL else {
            // also lands here for about:blank and about:home
            addressBarString = ""
            passiveAddressBarString = ""
            return
        }

        addressBarString = url.absoluteString
        updatePassiveAddressBarString(showURL: appearancePreferences.showFullURL, url: url, hostURL: hostURL)
    }

    private func updatePassiveAddressBarString(showURL: Bool, url: URL, hostURL: URL) {
        if showURL {
            passiveAddressBarString = url.toString(decodePunycode: true, dropScheme: false, dropTrailingSlash: true)
        } else {
            passiveAddressBarString = hostURL.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true).droppingWwwPrefix()
        }
    }

    private func updateTitle() { // swiftlint:disable:this cyclomatic_complexity
        let title: String
        switch tab.content {
        // keep an old tab title for web page terminated page, display "Failed to open page" for loading errors
        case _ where isShowingErrorPage && (tab.error?.code != .webContentProcessTerminated || tab.title == nil):
            if tab.error?.errorCode == NSURLErrorServerCertificateUntrusted {
                title = UserText.sslErrorPageTabTitle
            } else {
                title = UserText.tabErrorTitle
            }
        case .dataBrokerProtection:
            title = UserText.tabDataBrokerProtectionTitle
        case .settings:
            title = UserText.tabPreferencesTitle
        case .bookmarks:
            title = UserText.tabBookmarksTitle
        case .newtab:
            if tab.burnerMode.isBurner {
                title = UserText.burnerTabHomeTitle
            } else {
                title = UserText.tabHomeTitle
            }
        case .onboarding:
            title = UserText.tabOnboardingTitle
        case .url, .none, .subscription, .identityTheftRestoration:
            if let tabTitle = tab.title?.trimmingWhitespace(), !tabTitle.isEmpty {
                title = tabTitle
            } else if let host = tab.url?.host?.droppingWwwPrefix() {
                title = host
            } else if let url = tab.url, url.isFileURL {
                title = url.lastPathComponent
            } else {
                title = addressBarString
            }
        }
        if self.title != title {
            self.title = title
        }
    }

    private func updateFavicon(_ tabFavicon: NSImage?? = .none /* provided from .sink or taken from tab.favicon (optional) if .none */) {
        guard !isShowingErrorPage else {
            favicon = errorFaviconToShow(error: tab.error)
            return
        }
        switch tab.content {
        case .dataBrokerProtection:
            favicon = Favicon.dataBrokerProtection
            return
        case .newtab:
            if tab.burnerMode.isBurner {
                favicon = Favicon.burnerHome
            } else {
                favicon = Favicon.home
            }
            return
        case .settings:
            favicon = Favicon.preferences
            return
        case .bookmarks:
            favicon = Favicon.bookmarks
            return
        case .subscription:
            favicon = Favicon.subscription
            return
        case .identityTheftRestoration:
            favicon = Favicon.identityTheftRestoration
            return
        case .url, .onboarding, .none: break
        }

        if let favicon: NSImage? = tabFavicon {
            self.favicon = favicon
        } else {
            self.favicon = tab.favicon
        }
    }

    func reload() {
        tab.reload()
        updateAddressBarStrings()
    }

    private func errorFaviconToShow(error: WKError?) -> NSImage {
        if error?.errorCode == NSURLErrorServerCertificateUntrusted {
            return .redAlertCircle16
        }
        return.alertCircleColor16
    }

    // MARK: - Privacy icon animation

    let trackersAnimationTriggerPublisher = PassthroughSubject<Void, Never>()
    let privacyEntryPointIconUpdateTrigger = PassthroughSubject<Void, Never>()

    private var trackerAnimationTimer: Timer?

    private func sendAnimationTrigger() {
        privacyEntryPointIconUpdateTrigger.send()
        if self.tab.privacyInfo?.trackerInfo.trackersBlocked.count ?? 0 > 0 {
            self.trackersAnimationTriggerPublisher.send()
        }
    }

}

extension TabViewModel {

    func showFindInPage() {
        tab.findInPage?.show(with: tab.webView)
    }

    func closeFindInPage() {
        tab.findInPage?.close()
    }

    func findInPageNext() {
        tab.findInPage?.findNext()
    }

    func findInPagePrevious() {
        tab.findInPage?.findPrevious()
    }

}

extension TabViewModel: TabDataClearing {

    @MainActor
    func prepareForDataClearing(caller: TabCleanupPreparer) {
        tab.prepareForDataClearing(caller: caller)
    }

}
