//
//  Tab.swift
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
import WebKit

class Tab {

    init(faviconService: FaviconService) {
        self.faviconService = faviconService
        webView = WebView(frame: CGRect.zero, configuration: WKWebViewConfiguration.makeConfiguration())

        setupWebView()
        setupUserScripts()
    }

    convenience init() {
        self.init(faviconService: LocalFaviconService.shared)
    }

    deinit {
        webView.stopLoading()
    }

    let webView: WebView

    @Published var url: URL? {
        didSet {
            if oldValue?.host != url?.host {
                fetchFavicon(nil, for: url?.host)
            }
        }
    }
    @Published var title: String?

    func goForward() {
        webView.goForward()
    }

    func goBack() {
        webView.goBack()
    }

    func goHome() {
        url = nil
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    private func setupWebView() {
        webView.allowsBackForwardNavigationGestures = true
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?
    let faviconService: FaviconService

    private func fetchFavicon(_ faviconURL: URL?, for host: String?) {
        favicon = nil

        guard let host = host else {
            return
        }

        faviconService.fetchFavicon(faviconURL, for: host) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
        }
    }

    // MARK: - User Scripts

    let faviconScript = FaviconUserScript()

    private func setupUserScripts() {
        faviconScript.delegate = self
        webView.configuration.userContentController.add(userScript: faviconScript)
    }

}

extension Tab: Equatable {

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

}

extension Tab: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript, didFindFavicon faviconUrl: URL) {
        guard let host = url?.host else {
            return
        }

        faviconService.fetchFavicon(faviconUrl, for: host) { (image, error) in
            guard error == nil, let image = image else {
                return
            }

            self.favicon = image
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
