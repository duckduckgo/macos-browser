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
    private let navigationViewModel: ContainerNavigationViewModel
    private let profileViewModel: ProfileViewModel
    private let dataManager: DataBrokerProtectionDataManaging
    private let resultsViewModel: ResultsViewModel
    private let containerViewModel: ContainerViewModel
    private let scheduler: DataBrokerProtectionScheduler
    private let notificationCenter: NotificationCenter
    private var webView: WKWebView?

    private let webUIViewModel: DBPUIViewModel

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
                <input type="button" value="Add Name" onclick="addName()">
                <input type="button" value="Add Address" onclick="addAddress()">
                <input type="button" value="Set Birth Year" onclick="setBirthYear()">
                <input type="button" value="Set State" onclick="handshake()">
                <input type="button" value="Get Profile" onclick="getProfile()">
                <input type="button" value="Start Scan" onclick="startScan()">
                <input type="button" value="Initial Scan Data" onclick="initialScanStatus()">
                <input type="button" value="Remove All Data" onclick="removeAllData()">
            </form>

            <p id="output"></p>

            <script type="text/javascript">
                function addName() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "addNameToCurrentUserProfile",
                        "id": "abc123",
                        "params": {
                            "first": "Bradley",
                            "middle": "Curtis",
                            "last": "Slayter"
                        }
                    })
                }

                function addAddress() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "addAddressToCurrentUserProfile",
                        "id": "abc123",
                        "params": {
                            "street": "3003 Lake Ridge Dr",
                            "city": "Sanger",
                            "state": "TX"
                        }
                    })
                }

                function setBirthYear() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "setBirthYearForCurrentUserProfile",
                        "params": {
                            "year": 1993
                        }
                    })
                }

                function startScan() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "startScanAndOptOut"
                    })
                }

                function removeAllData() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "deleteUserProfileData"
                    })
                }

                function handshake() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "setState",
                        "id": "abc123",
                        "params": {
                            "state": "ProfileReview"
                        }
                    })
                }

                function handshake() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "setState",
                        "id": "abc123",
                        "params": {
                            "state": "ProfileReview"
                        }
                    })
                }

                function getProfile() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "getCurrentUserProfile",
                        "id": "abc123",
                    }).then(data => {
                        document.getElementById('output').textContent = JSON.stringify(data, null, 4)
                    })
                }

                function initialScanStatus() {
                    window.webkit.messageHandlers.dbpui.postMessage({
                        "context": "dbpui",
                        "featureName": "dbpuiCommunication",
                        "method": "initialScanStatus",
                        "id": "abc123",
                    }).then(data => {
                        document.getElementById('output').textContent = JSON.stringify(data, null, 4)
                    })
                }
            </script>
        </body>
        </html>
    """

    public init(scheduler: DataBrokerProtectionScheduler,
                dataManager: DataBrokerProtectionDataManaging,
                notificationCenter: NotificationCenter = .default,
                privacyConfig: PrivacyConfigurationManaging? = nil, prefs: ContentScopeProperties? = nil) {
        self.scheduler = scheduler
        self.dataManager = dataManager
        self.notificationCenter = notificationCenter

        self.webUIViewModel = DBPUIViewModel(dataManager: dataManager, scheduler: scheduler, privacyConfig: privacyConfig, prefs: prefs, webView: webView)

        navigationViewModel = ContainerNavigationViewModel(dataManager: dataManager)
        profileViewModel = ProfileViewModel(dataManager: dataManager)

        resultsViewModel = ResultsViewModel(dataManager: dataManager,
                                            notificationCenter: notificationCenter)

        containerViewModel = ContainerViewModel(scheduler: scheduler,
                                                dataManager: dataManager)

        dataManager.fetchProfile(ignoresCache: true)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        let containerView = DataBrokerProtectionContainerView(
            containerViewModel: containerViewModel,
            navigationViewModel: navigationViewModel,
            profileViewModel: profileViewModel,
            resultsViewModel: resultsViewModel)

        let hostingController = NSHostingController(rootView: containerView)
        view = hostingController.view

//        guard let configuration = webUIViewModel.setupCommunicationLayer() else { return }
//
//        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
//        view = webView!

        // FOR LOCAL WEB UI DEVELOPMENT:
        // Comment this line 👇
//        webView?.loadHTMLString(debugPage, baseURL: nil)
        // Uncomment this line and add your dev URL 👇
//        webView?.load(URL(string: "https://<your url>")!)
    }

}
