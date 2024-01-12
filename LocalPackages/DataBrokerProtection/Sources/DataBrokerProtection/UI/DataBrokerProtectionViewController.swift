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
import BrowserServicesKit
import WebKit
import Combine

final public class DataBrokerProtectionViewController: NSViewController {
    private let dataManager: DataBrokerProtectionDataManaging
    private let scheduler: DataBrokerProtectionScheduler
    private var webView: WKWebView?
    private let webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable
    private let webUIViewModel: DBPUIViewModel

    private let openURLHandler: (URL?) -> Void

    public init(scheduler: DataBrokerProtectionScheduler,
                dataManager: DataBrokerProtectionDataManaging,
                privacyConfig: PrivacyConfigurationManaging? = nil,
                prefs: ContentScopeProperties? = nil,
                webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
                openURLHandler: @escaping (URL?) -> Void) {
        self.scheduler = scheduler
        self.dataManager = dataManager
        self.openURLHandler = openURLHandler
        self.webUISettings = webUISettings
        self.webUIViewModel = DBPUIViewModel(dataManager: dataManager,
                                             scheduler: scheduler,
                                             webUISettings: webUISettings,
                                             privacyConfig: privacyConfig,
                                             prefs: prefs,
                                             webView: webView)

        Task {
            _ = dataManager.fetchProfile(ignoresCache: true)
        }

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: DataBrokerProtectionNotifications.shouldReloadUI,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.webView?.reload()
        }
    }

    override public func loadView() {
        guard let configuration = webUIViewModel.setupCommunicationLayer() else { return }

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        webView?.uiDelegate = self
        view = webView!

        if let url = URL(string: webUISettings.selectedURL) {
            webView?.load(url)
        } else {
            assertionFailure("Selected URL is not valid \(webUISettings.selectedURL)")
        }

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension DataBrokerProtectionViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        openURLHandler(navigationAction.request.url)
        return nil
    }
}
