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
import WebKit

class TabViewModel {

    private enum Constants {
        static let homeTitle = "Home"
        static let homeFaviconImage = NSImage(named: "HomeFavicon")!
    }

    private(set) var tab: Tab
    private var cancelables = Set<AnyCancellable>()

    var webView: WebView {
        didSet {
            webViewStateObserver = WebViewStateObserver(webView: webView, tabViewModel: self)
        }
    }
    
    private var webViewStateObserver: WebViewStateObserver?

    @Published var canGoForward: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canReload: Bool = false
    @Published var isLoading: Bool = false

    @Published private(set) var addressBarString: String = ""
    @Published private(set) var title: String = Constants.homeTitle
    @Published private(set) var favicon: NSImage = Constants.homeFaviconImage

    init(tab: Tab) {
        self.tab = tab

        webView = WebView(frame: CGRect.zero, configuration: WKWebViewConfiguration.makeConfiguration())
        webViewStateObserver = WebViewStateObserver(webView: webView, tabViewModel: self)

        bindUrl()
        bindTitle()
        bindFavicon()
    }

    private func bindUrl() {
        tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanReaload()
            self?.updateAddressBarString()
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

    private func updateAddressBarString() {
        guard let url = tab.url else {
            addressBarString = ""
            return
        }

        if let searchQuery = url.searchQuery {
            addressBarString = searchQuery
        } else if url == URL.emptyPage {
            addressBarString = ""
        } else {
            addressBarString = url.absoluteString
                .dropPrefix(URL.Scheme.https.separated())
                .dropPrefix(URL.Scheme.http.separated())
        }
    }

    private func updateTitle() {
        if tab.url == nil {
            title = Constants.homeTitle
            return
        }

        if let title = tab.title {
            self.title = title
        } else {
            title = addressBarString
        }
    }

    private func updateFavicon() {
        if tab.url == nil {
            favicon = Constants.homeFaviconImage
            return
        }

        if let favicon = tab.favicon {
            self.favicon = favicon
        } else {
            //todo default favicon
            favicon = NSImage()
        }
    }
    
}

fileprivate extension WKWebViewConfiguration {

    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsAirPlayForMediaPlayback = true
        return configuration
    }

}
