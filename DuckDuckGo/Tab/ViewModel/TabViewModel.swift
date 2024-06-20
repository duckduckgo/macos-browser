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
        static let duckPlayer = NSImage.duckPlayerSettings
        static let burnerHome = NSImage.burnerTabFavicon
        static let settings = NSImage.settingsMulticolor16
        static let bookmarks = NSImage.bookmarksFolder
        static let emailProtection = NSImage.emailProtectionIcon
        static let dataBrokerProtection = NSImage.personalInformationRemovalMulticolor16
        static let subscription = NSImage.privacyPro
        static let identityTheftRestoration = NSImage.identityTheftRestorationMulticolor16
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
    @Published private(set) var passiveAddressBarAttributedString = NSAttributedString()

    var lastAddressBarTextFieldValue: AddressBarTextField.Value?

    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage?
    var findInPage: FindInPageModel? { tab.findInPage?.model }

    @Published private(set) var usedPermissions = Permissions()
    @Published private(set) var permissionAuthorizationQuery: PermissionAuthorizationQuery?

    let zoomLevelSubject = PassthroughSubject<DefaultZoomValue, Never>()
    private (set) var zoomLevel: DefaultZoomValue = .percent100 {
        didSet {
            self.tab.webView.zoomLevel = zoomLevel
            if oldValue != zoomLevel {
                zoomLevelSubject.send(zoomLevel)
            }
        }
    }

    var canPrint: Bool {
        !isShowingErrorPage && canReload && tab.webView.canPrint
    }

    var canSaveContent: Bool {
        !isShowingErrorPage && canReload && !tab.webView.isInFullScreenMode
    }

    var canFindInPage: Bool {
        guard !isShowingErrorPage else { return false }
        switch tab.content {
        case .url(let url, _, _):
            return !(url.isDuckPlayer || url.isDuckURLScheme)
        case .subscription, .identityTheftRestoration:
            return true

        case .newtab, .settings, .bookmarks, .onboardingDeprecated, .onboarding, .dataBrokerProtection, .none:
            return false
        }
    }

    init(tab: Tab,
         appearancePreferences: AppearancePreferences = .shared,
         accessibilityPreferences: AccessibilityPreferences = .shared) {
        self.tab = tab
        self.appearancePreferences = appearancePreferences
        self.accessibilityPreferences = accessibilityPreferences
        zoomLevel = accessibilityPreferences.defaultPageZoom
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
        tab.$content
            .map { [tab] content -> AnyPublisher<Void, Never> in
                switch content {
                case .url(_, _, source: .userEntered(_, downloadRequested: true)):
                    // don‘t update the address bar for download navigations
                    return Empty().eraseToAnyPublisher()

                case .url(let url, _, source: .webViewUpdated),
                        .url(let url, _, source: .link):

                    guard !url.isEmpty, url != .blankPage, !url.isDuckPlayer else { fallthrough }

                    // Only display the Tab content URL update matching its Security Origin
                    // see https://github.com/mozilla-mobile/firefox-ios/wiki/WKWebView-navigation-and-security-considerations
                    return tab.$securityOrigin
                        .filter { tabSecurityOrigin in
                            url.securityOrigin == tabSecurityOrigin
                        }
                        .asVoid().eraseToAnyPublisher()

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
                        .onboardingDeprecated,
                        .none,
                        .dataBrokerProtection,
                        .subscription,
                        .identityTheftRestoration:
                    // Update the address bar instantly for built-in content types or user-initiated navigations
                    return Just( () ).eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .sink { [weak self] _ in
                guard let self else { return }

                updateAddressBarStrings()
                updateFavicon()
                updateCanBeBookmarked()
                updateZoomForWebsite()
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
        self.tab.webView.zoomLevelDelegate = self
        appearancePreferences.$showFullURL.dropFirst().sink { [weak self] showFullURL in
            self?.updatePassiveAddressBarString(showFullURL: showFullURL)
        }.store(in: &cancellables)
        accessibilityPreferences.$defaultPageZoom.sink { [weak self] newValue in
            guard let self = self else { return }
            self.tab.webView.defaultZoomValue = newValue
            if !isThereZoomPerWebsite {
                self.zoomLevel = newValue
            }
        }.store(in: &cancellables)
        accessibilityPreferences.zoomPerWebsiteUpdatedSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateZoomForWebsite()
            }.store(in: &cancellables)
    }

    private var isThereZoomPerWebsite: Bool {
        guard let urlString = tab.url?.absoluteString else { return false }
        guard !tab.burnerMode.isBurner else { return false }
        return accessibilityPreferences.zoomPerWebsite(url: urlString) != nil
    }

    private func updateZoomForWebsite() {
        guard let urlString = tab.url?.absoluteString else { return }
        guard !tab.burnerMode.isBurner else { return }
        let zoomToApply: DefaultZoomValue = accessibilityPreferences.zoomPerWebsite(url: urlString) ?? accessibilityPreferences.defaultPageZoom
        self.zoomLevel = zoomToApply
    }

    private func subscribeToWebViewDidFinishNavigation() {
        tab.webViewDidFinishNavigationPublisher.sink { [weak self] in
            guard let self = self else { return }
            self.sendAnimationTrigger()
            self.updateZoomForWebsite()
        }.store(in: &cancellables)
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = !isShowingErrorPage && tab.content.canBeBookmarked
    }

    private func updateAddressBarStrings() {
        updateAddressBarString()
        updatePassiveAddressBarString()
    }

    private func updateAddressBarString() {
        addressBarString = {
            guard ![.none, .onboardingDeprecated, .newtab].contains(tab.content),
                  let url = tab.content.userEditableUrl else { return "" }

            if url.isBlobURL {
                return url.strippingUnsupportedCredentials()
            }
            return url.absoluteString
        }()
    }

    private func updatePassiveAddressBarString(showFullURL: Bool? = nil) {
        let showFullURL = showFullURL ?? appearancePreferences.showFullURL
        passiveAddressBarAttributedString = switch tab.content {
        case .newtab, .onboardingDeprecated, .onboarding, .none:
                .init() // empty
        case .settings:
                .settingsTrustedIndicator
        case .bookmarks:
                .bookmarksTrustedIndicator
        case .dataBrokerProtection:
                .dbpTrustedIndicator
        case .subscription:
                .subscriptionTrustedIndicator
        case .identityTheftRestoration:
                .identityTheftRestorationTrustedIndicator
        case .url(let url, _, _) where url.isDuckPlayer:
                .duckPlayerTrustedIndicator
        case .url(let url, _, _) where url.isEmailProtection:
                .emailProtectionTrustedIndicator
        case .url(let url, _, _):
            NSAttributedString(string: passiveAddressBarString(with: url, showFullURL: showFullURL))
        }
    }

    private func passiveAddressBarString(with url: URL, showFullURL: Bool) -> String {
        if url.isBlobURL {
            url.strippingUnsupportedCredentials()

        } else if url.isDataURL {
            "data:"

        } else if !showFullURL && url.isFileURL {
            url.lastPathComponent

        } else if !showFullURL && url.host?.isEmpty == false {
            url.root?.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true).droppingWwwPrefix() ?? ""

        } else /* display full url */ {
            url.toString(decodePunycode: true, dropScheme: false, dropTrailingSlash: true)
        }
    }

    private func updateTitle() { // swiftlint:disable:this cyclomatic_complexity
        var title: String
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
        case .onboardingDeprecated:
            title = UserText.tabOnboardingTitle
        case .url, .none, .subscription, .identityTheftRestoration, .onboarding:
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
        if title.isEmpty {
            title = UserText.tabUntitledTitle
        }
        if self.title != title {
            self.title = title
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateFavicon(_ tabFavicon: NSImage?? = .none /* provided from .sink or taken from tab.favicon (optional) if .none */) {
        guard !isShowingErrorPage else {
            favicon = errorFaviconToShow(error: tab.error)
            return
        }
        favicon = switch tab.content {
        case .dataBrokerProtection:
            Favicon.dataBrokerProtection
        case .newtab where tab.burnerMode.isBurner:
            Favicon.burnerHome
        case .newtab:
            Favicon.home
        case .settings:
            Favicon.settings
        case .bookmarks:
            Favicon.bookmarks
        case .subscription:
            Favicon.subscription
        case .identityTheftRestoration:
            Favicon.identityTheftRestoration
        case .url(let url, _, _) where url.isDuckPlayer:
            Favicon.duckPlayer
        case .url(let url, _, _) where url.isEmailProtection:
            Favicon.emailProtection
        case .url, .onboardingDeprecated, .onboarding, .none:
            tabFavicon ?? tab.favicon
        }
    }

    func reload() {
        tab.reload()
        updateAddressBarStrings()
        self.updateZoomForWebsite()
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

extension TabViewModel: WebViewZoomLevelDelegate {
    func zoomWasSet(to level: DefaultZoomValue) {
        zoomLevel = level
        guard let urlString = tab.url?.absoluteString else { return }
        guard !tab.burnerMode.isBurner else { return }
        if accessibilityPreferences.zoomPerWebsite(url: urlString) != level {
            accessibilityPreferences.updateZoomPerWebsite(zoomLevel: level, url: urlString)
        }
    }
}

private extension NSAttributedString {

    private typealias Component = NSAttributedString

    private static let spacer = NSImage() // empty spacer image attachment for Attributed Strings below

    private static let iconBaselineOffset: CGFloat = -3
    private static let iconSize: CGFloat = 16
    private static let iconSpacing: CGFloat = 6
    private static let chevronSize: CGFloat = 12
    private static let chevronSpacing: CGFloat = 12

    private static let duckDuckGoWithChevronAttributedString = NSAttributedString {
        // logo
        Component(image: .homeFavicon, rect: CGRect(x: 0, y: iconBaselineOffset, width: iconSize, height: iconSize))
        // spacing
        Component(image: spacer, rect: CGRect(x: 0, y: 0, width: iconSpacing, height: 1))
        // DuckDuckGo
        Component(string: UserText.duckDuckGo)

        // spacing (wide)
        Component(image: spacer, rect: CGRect(x: 0, y: 0, width: chevronSpacing, height: 1))
        // chevron
        Component(image: .chevronRight12, rect: CGRect(x: 0, y: -1, width: chevronSize, height: chevronSize))
        // spacing (wide)
        Component(image: spacer, rect: CGRect(x: 0, y: 0, width: chevronSpacing, height: 1))
    }

    private static func trustedIndicatorAttributedString(with icon: NSImage, title: String) -> NSAttributedString {
        NSAttributedString {
            duckDuckGoWithChevronAttributedString

            // favicon
            Component(image: icon, rect: CGRect(x: 0, y: iconBaselineOffset, width: icon.size.width, height: icon.size.height))
            // spacing
            Component(image: spacer, rect: CGRect(x: 0, y: 0, width: iconSpacing, height: 1))
            // title
            Component(string: title)
        }
    }

    static let settingsTrustedIndicator = trustedIndicatorAttributedString(with: .settingsMulticolor16,
                                                                           title: UserText.settings)
    static let bookmarksTrustedIndicator = trustedIndicatorAttributedString(with: .bookmarksFolder,
                                                                            title: UserText.bookmarks)
    static let dbpTrustedIndicator = trustedIndicatorAttributedString(with: .personalInformationRemovalMulticolor16,
                                                                      title: UserText.tabDataBrokerProtectionTitle)
    static let subscriptionTrustedIndicator = trustedIndicatorAttributedString(with: .privacyPro,
                                                                               title: UserText.subscription)
    static let identityTheftRestorationTrustedIndicator = trustedIndicatorAttributedString(with: .identityTheftRestorationMulticolor16,
                                                                                           title: UserText.identityTheftRestorationOptionsMenuItem)
    static let duckPlayerTrustedIndicator = trustedIndicatorAttributedString(with: .duckPlayerSettings,
                                                                             title: UserText.duckPlayer)
    static let emailProtectionTrustedIndicator = trustedIndicatorAttributedString(with: .emailProtectionIcon,
                                                                                  title: UserText.emailProtectionPreferences)

}
