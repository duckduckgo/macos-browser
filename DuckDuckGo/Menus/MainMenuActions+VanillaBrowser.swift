//
//  MainMenuActions+VanillaBrowser.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation
import BareBonesBrowserKit
import SwiftUI

extension MainViewController: BareBonesBrowserUIDelegate {

    fileprivate static let ddgURL = URL(string: "https://duckduckgo.com/")!
    @objc func openVanillaBrowser(_ sender: Any?) {
        let currentURL = WindowControllersManager.shared.selectedTab?.url ?? MainViewController.ddgURL
        openVanillaBrowser(url: currentURL)
    }

    static var webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.processPool = WKProcessPool()
        return configuration
    }()

    private func openVanillaBrowser(url: URL) {
        let browserView = NSHostingView(rootView: BareBonesBrowserView(initialURL: url,
                                                                       homeURL: MainViewController.ddgURL,
                                                                       uiDelegate: self,
                                                                       configuration: Self.webViewConfiguration,
                                                                       userAgent: UserAgent.brandedDefault))
        browserView.translatesAutoresizingMaskIntoConstraints = false
        browserView.widthAnchor.constraint(greaterThanOrEqualToConstant: 640).isActive = true
        browserView.heightAnchor.constraint(greaterThanOrEqualToConstant: 480).isActive = true
        let viewController = NSViewController()
        viewController.view = browserView
        let window = NSWindow(contentViewController: viewController)
        window.center()
        window.title = "Vanilla browser"
        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
    }

    func browserDidRequestNewWindow(urlRequest: URLRequest) {
        if let url = urlRequest.url {
            openVanillaBrowser(url: url)
        }
    }
}
