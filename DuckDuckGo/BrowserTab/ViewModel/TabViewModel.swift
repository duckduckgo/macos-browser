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
        static let defaultFavicon = NSImage()
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

    @Published var credentialsToSave: SecureVaultModels.WebsiteCredentials?

    var loadingStartTime: CFTimeInterval?

    @Published private(set) var addressBarString: String = ""
    @PublishedAfter private(set) var passiveAddressBarString: String = ""
    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage = Favicon.home
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
        tab.$content.sink { [weak self] _ in
            self?.updateCanReload()
            self?.updateAddressBarStrings()
            self?.updateCanBeBookmarked()
        } .store(in: &cancellables)
    }

    private func subscribeToTitle() {
        tab.$title.sink { [weak self] _ in self?.updateTitle() } .store(in: &cancellables)
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
        tab.permissions.$permissions.weakAssign(to: \.usedPermissions, on: self)
            .store(in: &cancellables)
        tab.permissions.$authorizationQuery.weakAssign(to: \.permissionAuthorizationQuery, on: self)
            .store(in: &cancellables)
    }

    private func subscribeToWebViewDidFinishNavigation() {
        tab.webViewDidFinishNavigationPublisher.sink { [weak self] _ in
            self?.scheduleTrackerAnimation()
        }.store(in: &cancellables)
    }

    private func updateCanReload() {
        canReload = tab.content.url ?? .emptyPage != .emptyPage
    }

    func updateCanGoBack() {
        canGoBack = tab.canGoBack || tab.canBeClosedWithBack
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = tab.content.url ?? .emptyPage != .emptyPage
    }

    private func updateAddressBarStrings() {
        guard !errorViewState.isVisible else {
            let failingUrl = tab.error?.failingUrl
            addressBarString = failingUrl?.absoluteString ?? ""
            passiveAddressBarString = failingUrl?.host?.drop(prefix: URL.HostPrefix.www.separated()) ?? ""
            return
        }

        guard let url = tab.content.url else {
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

        guard let host = url.host else {
            addressBarString = ""
            passiveAddressBarString = ""
            return
        }

        if let searchQuery = url.searchQuery {
            addressBarString = searchQuery
            passiveAddressBarString = searchQuery
        } else if url == URL.emptyPage {
            addressBarString = ""
            passiveAddressBarString = ""
        } else {
            addressBarString = url.absoluteString
            passiveAddressBarString = host.drop(prefix: URL.HostPrefix.www.separated())
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
        case .homepage:
            title = UserText.tabHomeTitle
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
            favicon = Favicon.defaultFavicon
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
        case .url, .none: break
        }

        if let favicon = tab.favicon {
            self.favicon = favicon
        } else {
            favicon = Favicon.defaultFavicon
        }
    }

    // MARK: - Privacy icon animation

    let trackersAnimationTriggerPublisher = PassthroughSubject<Void, Never>()

    private var trackerAnimationTimer: Timer?

    private func scheduleTrackerAnimation() {
        trackerAnimationTimer?.invalidate()
        trackerAnimationTimer = nil
        trackerAnimationTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] _ in
            guard let self = self, !self.isLoading else { return }

            if self.tab.trackerInfo?.trackersBlocked.count ?? 0 > 0 {
                self.trackersAnimationTriggerPublisher.send()
            }

            self.trackerAnimationTimer?.invalidate()
            self.trackerAnimationTimer = nil
        })
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
