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

final public class DataBrokerProtectionViewController: NSViewController {
    private let navigationViewModel: ContainerNavigationViewModel
    private let profileViewModel: ProfileViewModel
    private let dataManager: DataBrokerProtectionDataManaging

    private let privacyConfig: PrivacyConfigurationManaging?
    private let prefs: ContentScopeProperties?

    private var communicationLayer: DBPUICommunicationLayer?
    private var webView: WKWebView?

    private let debugPage: String = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
</head>
<body>
    <form>
        <input type="button" value="setState" onclick="setState()">
        <input type="button" value="handshake" onclick="handshake()">
    </form>

    <script type="text/javascript">
        function setState() {
            window.webkit.messageHandlers.dbpui.postMessage({
                "context": "dbpui",
                "featureName": "dbpuiCommunication",
                "method": "setState",
                "params": {
                    "state": "Onboarding"
                }
            })
        }

        function handshake() {
            window.webkit.messageHandlers.dbpui.postMessage({
                "context": "dbpui",
                "featureName": "dbpuiCommunication",
                "method": "handshake",
                "params": {
                    "version": 1
                }
            })
        }
    </script>
</body>
</html>
"""

    public init(privacyConfig: PrivacyConfigurationManaging? = nil, prefs: ContentScopeProperties? = nil) {
        dataManager = DataBrokerProtectionDataManager()
        navigationViewModel = ContainerNavigationViewModel(dataManager: dataManager)
        profileViewModel = ProfileViewModel(dataManager: dataManager)

        self.privacyConfig = privacyConfig
        self.prefs = prefs

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        if #available(macOS 11.0, *) {
//            let containerView = DataBrokerProtectionContainerView(navigationViewModel: navigationViewModel,
//                                                                  profileViewModel: profileViewModel)
//
//            let hostingController = NSHostingController(rootView: containerView)
//            view = hostingController.view

            guard let privacyConfig = privacyConfig else { return }
            guard let prefs = prefs else { return }

            let configuration = WKWebViewConfiguration()
            configuration.applyDBPUIConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: self)
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

            if let dbpUIContentController = configuration.userContentController as? DBPUIUserContentController {
                communicationLayer = dbpUIContentController.dbpUIUserScripts.dbpUICommunicationLayer
            }

            webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
            view = webView!

            webView?.loadHTMLString(debugPage, baseURL: nil)

            let button = NSButton(title: "Set State", target: self, action: #selector(setUIState))
            button.setButtonType(.momentaryLight)
            button.contentTintColor = .black
            button.frame = CGRect(x: 10, y: 100, width: 100, height: 50)
            view.addSubview(button)
        }
    }

    @objc func setUIState() {
        guard let webView = webView else { return }
        communicationLayer?.sendMessageToUI(method: .setState,
                                            params: DBPUIWebSetState(state: .onboarding),
                                            into: webView)
    }

}

extension DataBrokerProtectionViewController: DBPUICommunicationDelegate {
    func setState() {

    }

    func getUserProfile() -> DBPUIUserProfile? {
        return dataManager.fetchProfileForUI()
    }

    func addNameToCurrentUserProfile(_ name: DBPUIUserProfileName) -> Bool {
        return false
    }

    func removeNameFromUserProfile(_ name: DBPUIUserProfileName) -> Bool {
        return false
    }

    func removeNameAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool {
        return false
    }

    func setBirthYearForCurrentUserProfile(_ year: DBPUIBirthYear) {

    }

    func addAddressToCurrentUserProfile(_ address: DBPUIUserProfileAddress) -> Bool {
        return false
    }

    func removeAddressFromCurrentUserProfile(_ address: DBPUIUserProfileAddress) -> Bool {
        return false
    }

    func removeAddressAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool {
        return false
    }

    func startScanAndOptOut() -> Bool {
        return false
    }

}
