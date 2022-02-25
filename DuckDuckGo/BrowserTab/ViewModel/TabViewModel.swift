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
    private var cancellables = Set<AnyCancellable>()
    
    private var webViewStateObserver: WebViewStateObserver?

    @Published var canGoForward: Bool = false
    @Published private(set) var canGoBack: Bool = false
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
    var lastHomepageTextFieldValue: AddressBarTextField.Value?

    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage?
    @Published private(set) var findInPage: FindInPageModel = FindInPageModel()

    @Published private(set) var usedPermissions = Permissions()
    @Published private(set) var permissionAuthorizationQuery: PermissionAuthorizationQuery?

    init(tab: Tab) {
        self.tab = tab

        webViewStateObserver = WebViewStateObserver(webView: tab.webView, tabViewModel: self)

        subscribeToUrl()
        subscribeToTitle()
        subscribeToFavicon()
        subscribeToTabError()
        subscribeToPermissions()
        subscribeToWebViewDidFinishNavigation()
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
        tab.$title.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.updateTitle() } .store(in: &cancellables)
    }

    private func subscribeToFavicon() {
        tab.$favicon.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.updateFavicon() } .store(in: &cancellables)
    }

    private func subscribeToTabError() {
        tab.$error.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.errorViewState.isVisible = self.tab.error != nil
            self.errorViewState.message = self.tab.error?.localizedDescription
        } .store(in: &cancellables)
    }

    private func subscribeToPermissions() {
        tab.permissions.$permissions.assign(to: \.usedPermissions, onWeaklyHeld: self)
            .store(in: &cancellables)
        tab.permissions.$authorizationQuery.assign(to: \.permissionAuthorizationQuery, onWeaklyHeld: self)
            .store(in: &cancellables)
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
        canGoBack = tab.canGoBack || tab.canBeClosedWithBack
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = tab.content.url ?? .blankPage != .blankPage
    }

    private func updateAddressBarStrings() {
        guard !errorViewState.isVisible else {
            let failingUrl = tab.error?.failingUrl
            addressBarString = failingUrl?.absoluteString ?? ""
            passiveAddressBarString = failingUrl?.host?.drop(prefix: URL.HostPrefix.www.separated()) ?? ""
            return
        }

        guard let url = tab.content.url ?? tab.parentTab?.content.url else {
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

        guard let host = url.host ?? tab.parentTab?.content.url?.host else {
            // also lands here for about:blank and about:home
            addressBarString = ""
            passiveAddressBarString = ""
            return
        }

        addressBarString = url.absoluteString
        passiveAddressBarString = host.drop(prefix: URL.HostPrefix.www.separated())
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
        case .homepage:
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
        case .homepage:
            favicon = Favicon.home
            return
        case .preferences:
            favicon = Favicon.preferences
            return
        case .bookmarks:
            favicon = Favicon.bookmarks
            return
        case .url, .onboarding, .none: break
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
