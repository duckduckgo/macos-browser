//
//  DataBrokerProtectionViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SwiftUI
import Common
import BrowserServicesKit
import PixelKit
import WebKit
import Combine

final public class DataBrokerProtectionViewController: NSViewController {
    private let dataManager: DataBrokerProtectionDataManaging
    private var webView: WKWebView?
    private var loader: NSProgressIndicator!
    private let webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable
    private let webUIViewModel: DBPUIViewModel
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let webUIPixel: DataBrokerProtectionWebUIPixels

    private let openURLHandler: (URL?) -> Void
    private var reloadObserver: NSObjectProtocol?

    public init(agentInterface: DataBrokerProtectionAppToAgentInterface,
                dataManager: DataBrokerProtectionDataManaging,
                privacyConfig: PrivacyConfigurationManaging? = nil,
                prefs: ContentScopeProperties? = nil,
                webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
                openURLHandler: @escaping (URL?) -> Void) {
        self.dataManager = dataManager
        self.openURLHandler = openURLHandler
        self.webUISettings = webUISettings
        self.pixelHandler = DataBrokerProtectionPixelsHandler()
        self.webUIPixel = DataBrokerProtectionWebUIPixels(pixelHandler: pixelHandler)
        self.webUIViewModel = DBPUIViewModel(dataManager: dataManager,
                                             agentInterface: agentInterface,
                                             webUISettings: webUISettings,
                                             privacyConfig: privacyConfig,
                                             prefs: prefs,
                                             webView: webView)

        // Prepare the profile cache to avoid stuttering later
        // It's in a task to avoid stuttering now
        Task {
            try? dataManager.prepareProfileCache()
        }

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        reloadObserver = NotificationCenter.default.addObserver(forName: DataBrokerProtectionNotifications.shouldReloadUI,
                                                                object: nil,
                                                                queue: .main) { [weak self] _ in
            self?.webView?.reload()
        }
    }

    override public func loadView() {
        guard let configuration = webUIViewModel.setupCommunicationLayer() else { return }

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        webView?.uiDelegate = self
        webView?.navigationDelegate = self
        view = webView!

        addLoadingIndicator()

        if let url = URL(string: webUISettings.selectedURL) {
            webUIPixel.firePixel(for: webUISettings.selectedURLType, type: .loading)
            webView?.load(url)
        } else {
            removeLoadingIndicator()
            assertionFailure("Selected URL is not valid \(webUISettings.selectedURL)")
        }
    }

    private func addLoadingIndicator() {
        loader = NSProgressIndicator()
        loader.wantsLayer = true
        loader.style = .spinning
        loader.controlSize = .regular
        loader.sizeToFit()
        loader.translatesAutoresizingMaskIntoConstraints = false
        loader.controlSize = .large
        view.addSubview(loader)

        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func removeLoadingIndicator() {
        loader.stopAnimation(nil)
        loader.removeFromSuperview()
    }

    deinit {
        if let reloadObserver {
            NotificationCenter.default.removeObserver(reloadObserver)
        }
    }
}

extension DataBrokerProtectionViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        openURLHandler(navigationAction.request.url)
        return nil
    }
}

extension DataBrokerProtectionViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        fireWebViewError(error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        fireWebViewError(error)
    }

    private func fireWebViewError(_ error: Error) {
        webUIPixel.firePixel(for: error)
        removeLoadingIndicator()
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
            // if there's no http status code to act on, exit and allow navigation
            return .allow
        }

        if statusCode >= 400 {
            webUIPixel.firePixel(for: NSError(domain: NSURLErrorDomain, code: statusCode))
            return .cancel
        }

        return .allow
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loader.startAnimation(nil)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        removeLoadingIndicator()

        webUIPixel.firePixel(for: webUISettings.selectedURLType, type: .success)
    }
}
