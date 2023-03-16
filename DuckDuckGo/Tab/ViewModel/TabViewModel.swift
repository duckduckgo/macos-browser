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

    @Published var canGoForward: Bool = false
    @Published var canGoBack: Bool = false

    @Published private(set) var canReload: Bool = false
    @Published var canBeBookmarked: Bool = false
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
    var findInPage: FindInPageModel? { tab.findInPage?.model }

    @Published private(set) var usedPermissions = Permissions()
    @Published private(set) var permissionAuthorizationQuery: PermissionAuthorizationQuery?

    init(tab: Tab, appearancePreferences: AppearancePreferences = .shared) {
        self.tab = tab
        self.appearancePreferences = appearancePreferences

        subscribeToUrl()
        subscribeToCanGoBackForward()
        subscribeToTitle()
        subscribeToFavicon()
        subscribeToTabError()
        subscribeToPermissions()
        subscribeToAppearancePreferences()
        subscribeToWebViewDidFinishNavigation()
        tab.$isLoading.combineLatest(tab.isAMPProtectionExtractingPublisher) { $0 || $1 }
            .assign(to: \.isLoading, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.$loadingProgress
            .assign(to: \.progress, onWeaklyHeld: self)
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

    private func subscribeToCanGoBackForward() {
        tab.$canGoBack
            .map { [weak tab] canGoBack in
                canGoBack || tab?.canBeClosedWithBack == true
            }
            .assign(to: \.canGoBack, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.$canGoForward
            .assign(to: \.canGoForward, onWeaklyHeld: self)
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFavicon()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabError() {
        tab.$error
            .map { error -> ErrorViewState in

                if let error = error, !error.isFrameLoadInterrupted, !error.isNavigationCancelled {
                    // don‘t show error for interrupted load like downloads and for cancelled loads
                    return .init(isVisible: true, message: error.localizedDescription)
                } else {
                    return .init(isVisible: false, message: nil)
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
        tab.webViewDidFinishNavigationPublisher.sink { [weak self] in
            self?.sendAnimationTrigger()
        }.store(in: &cancellables)
    }

    private func updateCanReload() {
        canReload = tab.content.url ?? .blankPage != .blankPage
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
            passiveAddressBarString = failingUrl?.host?.droppingWwwPrefix() ?? ""
            return
        }

        guard tab.content.isUrl, !tab.content.isPrivatePlayer, let url = tabURL else {
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
        case .url, .none, .privatePlayer:
            if let title = tab.title?.trimmingWhitespace(),
               !title.isEmpty {
                self.title = title
            } else if let host = tab.url?.host?.droppingWwwPrefix() {
                self.title = host
            } else {
                self.title = addressBarString
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
        case .url, .onboarding, .privatePlayer, .none: break
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

    func prepareForDataClearing(caller: TabDataCleaner) {
        tab.prepareForDataClearing(caller: caller)
    }

}
