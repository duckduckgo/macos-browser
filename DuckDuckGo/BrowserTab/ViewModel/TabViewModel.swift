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

class TabViewModel {

    enum Title {
        static let home = "Home"
    }

    enum Favicon {
        static let home = NSImage(named: "HomeFavicon")!
        static let defaultFavicon = NSImage()
    }

    private(set) var tab: Tab
    private var cancelables = Set<AnyCancellable>()
    
    private var webViewStateObserver: WebViewStateObserver?

    @Published var canGoForward: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canReload: Bool = false
    @Published var isLoading: Bool = false

    @Published private(set) var addressBarString: String = ""
    @Published private(set) var passiveAddressBarString: String = ""
    @Published private(set) var title: String = Title.home
    @Published private(set) var favicon: NSImage = Favicon.home

    init(tab: Tab) {
        self.tab = tab

        webViewStateObserver = WebViewStateObserver(webView: tab.webView, tabViewModel: self)

        bindUrl()
        bindTitle()
        bindFavicon()
    }

    private func bindUrl() {
        tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanReaload()
            self?.updateAddressBarStrings()
        } .store(in: &cancelables)
    }

    private func bindTitle() {
        tab.$title.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.updateTitle() } .store(in: &cancelables)
    }

    private func bindFavicon() {
        tab.$favicon.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.updateFavicon() } .store(in: &cancelables)
    }

    private func updateCanReaload() {
        self.canReload = self.tab.url != nil
    }

    private func updateAddressBarStrings() {
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
                .drop(prefix: URL.Scheme.https.separated())
                .drop(prefix: URL.Scheme.http.separated())
            passiveAddressBarString = host.drop(prefix: URL.HostPrefix.www.separated())
        }
    }

    private func updateTitle() {
        if tab.isHomepageLoaded {
            title = Title.home
            return
        }

        if let title = tab.title {
            self.title = title
        } else {
            title = addressBarString
        }
    }

    private func updateFavicon() {
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
