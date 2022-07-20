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

import Cocoa
import Combine
import os.log
import BrowserServicesKit

final class TabViewModel {

    enum Favicon {
        static let home = NSImage(named: "HomeFavicon")!
        static let preferences = NSImage(named: "Preferences")!
        static let bookmarks = NSImage(named: "Bookmarks")!
    }

    private(set) var tab: Tab
    private let appearancePreferences: AppearancePreferences
    private var cancellables = Set<AnyCancellable>()

    private var webViewStateObserver: WebViewStateObserver?

    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canReload: Bool = false
    @Published var canBeBookmarked: Bool = false
    @Published var isWebViewLoading: Bool = false
    @Published var isLoading: Bool = false {
        willSet {
            if newValue {
                loadingStartTime = CACurrentMediaTime()
            }
        }
    }
    @Published var progress: Double = 0.0

    struct ErrorViewState {
        var isVisible: Bool = false
        var message: String?
    }
    @Published var errorViewState = ErrorViewState() {
        didSet {
            updateAddressBarStrings()
            updateTitle()
            updateFavicon()
            updateCanGoBack()
            updateCanGoForward()
        }
    }

    @Published var autofillDataToSave: AutofillData?

    var loadingStartTime: CFTimeInterval?

    @Published private(set) var addressBarString: String = ""
    @Published private(set) var passiveAddressBarString: String = ""
    var lastAddressBarTextFieldValue: AddressBarTextField.Value?
    var lastHomePageTextFieldValue: AddressBarTextField.Value?

    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage?
    @Published private(set) var findInPage: FindInPageModel = FindInPageModel()

    @Published private(set) var usedPermissions = Permissions()
    @Published private(set) var permissionAuthorizationQuery: PermissionAuthorizationQuery?

    init(tab: Tab, appearancePreferences: AppearancePreferences = .shared) {
        self.tab = tab
        self.appearancePreferences = appearancePreferences

        webViewStateObserver = WebViewStateObserver(webView: tab.webView, tabViewModel: self)

        subscribeToUrl()
        subscribeToTitle()
        subscribeToFavicon()
        subscribeToTabError()
        subscribeToPermissions()
        subscribeToAppearancePreferences()
        subscribeToWebViewDidFinishNavigation()
        $isWebViewLoading.combineLatest(tab.$isAMPProtectionExtracting) { $0 || $1 }
            .assign(to: \.isLoading, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToUrl() {
        tab.$content.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanReload()
            self?.updateAddressBarStrings()
            self?.updateCanBeBookmarked()
            self?.updateFavicon()
        } .store(in: &cancellables)
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFavicon()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabError() {
        tab.$error
            .map { error -> ErrorViewState in
                switch error {
                case .none, // no error
                    // don‘t show error for interrupted load like downloads
                        .some(WebKitError.frameLoadInterrupted):
                    return .init(isVisible: false, message: nil)
                case .some(let error):
                    return .init(isVisible: true, message: error.localizedDescription)
                }
            }
            .assign(to: \.errorViewState, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToPermissions() {
        tab.permissions.$permissions.assign(to: \.usedPermissions, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.permissions.$authorizationQuery.assign(to: \.permissionAuthorizationQuery, onWeaklyHeld: self)
            .store(in: &cancellables)
    }
    
    private func subscribeToAppearancePreferences() {
        appearancePreferences.$showFullURL.dropFirst().sink { [weak self] newValue in
            guard let self = self, let url = self.tabURL, let host = self.tabHostURL else { return }
            self.updatePassiveAddressBarString(showURL: newValue, url: url, hostURL: host)
        }.store(in: &cancellables)
    }

    private func subscribeToWebViewDidFinishNavigation() {
        tab.webViewDidFinishNavigationPublisher.sink { [weak self] _ in
            self?.sendAnimationTrigger()
        }.store(in: &cancellables)
    }

    private func updateCanReload() {
        canReload = tab.content.url ?? .blankPage != .blankPage
    }

    func updateCanGoBack() {
        canGoBack = tab.canGoBack || tab.canBeClosedWithBack || tab.error != nil
    }

    func updateCanGoForward() {
        canGoForward = tab.canGoForward && tab.error == nil
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = tab.content.url ?? .blankPage != .blankPage
    }
    
    private var tabURL: URL? {
        return tab.content.url ?? tab.parentTab?.content.url
    }
    
    private var tabHostURL: URL? {
        return tabURL?.root
    }

    func updateAddressBarStrings() {
        guard !errorViewState.isVisible else {
            let failingUrl = tab.error?.failingUrl
            addressBarString = failingUrl?.absoluteString ?? ""
            passiveAddressBarString = failingUrl?.host?.drop(prefix: URL.HostPrefix.www.separated()) ?? ""
            return
        }

        guard let url = tabURL else {
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
            passiveAddressBarString = hostURL.toString(decodePunycode: true, dropScheme: true, needsWWW: false, dropTrailingSlash: true)
        }
    }

    private func updateTitle() {
        guard !errorViewState.isVisible else {
            title = UserText.tabErrorTitle
            return
        }

        switch tab.content {
        case .preferences:
            title = UserText.tabPreferencesTitle
        case .bookmarks:
            title = UserText.tabBookmarksTitle
        case .homePage:
            title = UserText.tabHomeTitle
        case .onboarding:
            title = UserText.tabOnboardingTitle
        case .url, .none:
            if let title = tab.title {
                self.title = title
            } else {
                title = addressBarString
            }
        }
    }

    private func updateFavicon() {
        guard !errorViewState.isVisible else {
            favicon = nil
            return
        }

        switch tab.content {
        case .homePage:
            favicon = Favicon.home
            return
        case .preferences:
            favicon = Favicon.preferences
            return
        case .bookmarks:
            favicon = Favicon.bookmarks
            return
        case .url (let url):
            if url.host == URL.duckDuckGo.host {
                favicon = Favicon.home
                return
            }
        case .onboarding, .none: break
        }

        if let favicon = tab.favicon {
            self.favicon = favicon
        } else {
            favicon = nil
        }
    }

    func reload() {
        tab.reload()
        updateAddressBarStrings()
    }

    // MARK: - Privacy icon animation

    let trackersAnimationTriggerPublisher = PassthroughSubject<Void, Never>()

    private var trackerAnimationTimer: Timer?

    private func sendAnimationTrigger() {
        if self.tab.trackerInfo?.trackersBlocked.count ?? 0 > 0 {
            self.trackersAnimationTriggerPublisher.send()
        }
    }

}

extension TabViewModel {

    func startFindInPage() {
        tab.findInPage = findInPage
        findInPage.show()
    }

    func closeFindInPage() {
        guard findInPage.visible else { return }
        tab.findDone()
        findInPage.hide()
    }

    func findInPageNext() {
        tab.findNext()
    }

    func findInPagePrevious() {
        tab.findPrevious()
    }

}

extension TabViewModel: TabDataClearing {

    func prepareForDataClearing(caller: TabDataCleaner) {
        webViewStateObserver?.stopObserving()

        tab.prepareForDataClearing(caller: caller)
    }

}
