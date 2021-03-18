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

final class TabViewModel {

    enum Favicon {
        static let home = NSImage(named: "HomeFavicon")!
        static let defaultFavicon = NSImage()
    }

    private(set) var tab: Tab
    private var cancellables = Set<AnyCancellable>()
    
    private var webViewStateObserver: WebViewStateObserver?

    @Published var canGoForward: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canReload: Bool = false
    @Published var canBeBookmarked: Bool = false
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var isErrorViewVisible: Bool = false {
        didSet {
            updateAddressBarStrings()
            updateTitle()
            updateFavicon()
        }
    }

    @Published private(set) var addressBarString: String = ""
    @Published private(set) var passiveAddressBarString: String = ""
    @Published private(set) var title: String = UserText.tabHomeTitle
    @Published private(set) var favicon: NSImage = Favicon.home
    @Published private(set) var findInPage: FindInPageModel = FindInPageModel()

    init(tab: Tab) {
        self.tab = tab

        webViewStateObserver = WebViewStateObserver(webView: tab.webView, tabViewModel: self)

        subscribeToUrl()
        subscribeToTitle()
        subscribeToFavicon()
        subscribeToTabError()
    }

    private func subscribeToUrl() {
        tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanReload()
            self?.updateAddressBarStrings()
            self?.updateCanBeBookmarked()
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
            self.isErrorViewVisible = self.tab.error != nil
        } .store(in: &cancellables)
    }

    private func updateCanReload() {
        canReload = tab.url != nil
    }

    private func updateCanBeBookmarked() {
        canBeBookmarked = tab.url != nil
    }

    private func updateAddressBarStrings() {
        guard !isErrorViewVisible else {
            let failingUrl = tab.error?.failingUrl
            addressBarString = failingUrl?.absoluteString ?? ""
            passiveAddressBarString = failingUrl?.host?.drop(prefix: URL.HostPrefix.www.separated()) ?? ""
            return
        }

        guard let url = tab.url, let host = url.host else {
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
        guard !isErrorViewVisible else {
            title = UserText.tabErrorTitle
            return
        }

        if tab.isHomepageLoaded {
            title = UserText.tabHomeTitle
            return
        }

        if let title = tab.title {
            self.title = title
        } else {
            title = addressBarString
        }
    }

    private func updateFavicon() {
        guard !isErrorViewVisible else {
            favicon = Favicon.defaultFavicon
            return
        }

        if tab.isHomepageLoaded {
            favicon = Favicon.home
            return
        }

        if let favicon = tab.favicon {
            self.favicon = favicon
        } else {
            favicon = Favicon.defaultFavicon
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
