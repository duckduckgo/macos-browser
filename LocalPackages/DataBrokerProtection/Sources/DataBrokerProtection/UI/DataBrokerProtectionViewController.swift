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
    private let resultsViewModel: ResultsViewModel
    private let containerViewModel: ContainerViewModel
    private let scheduler: DataBrokerProtectionScheduler
    private let notificationCenter: NotificationCenter

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
            <input type="button" value="Add Name" onclick="addName()">
            <input type="button" value="Add Address" onclick="addAddress()">
            <input type="button" value="Set Birth Year" onclick="setBirthYear()">
            <input type="button" value="Set State" onclick="handshake()">
            <input type="button" value="Get Profile" onclick="getProfile()">
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
                        "first": "John",
                        "middle": "Jacob",
                        "last": "JingleHeimerSchmidt"
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
                        "street": "123 easy ln",
                        "city": "Anytown",
                        "state": "TX"
                    }
                })
            }

            function setBirthYear() {
                let year = Math.floor(Math.random() * 10) + 1990
                window.webkit.messageHandlers.dbpui.postMessage({
                    "context": "dbpui",
                    "featureName": "dbpuiCommunication",
                    "method": "setBirthYearForCurrentUserProfile",
                    "params": {
                        "year": year
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
        self.privacyConfig = privacyConfig
        self.prefs = prefs

        navigationViewModel = ContainerNavigationViewModel(dataManager: dataManager)
        profileViewModel = ProfileViewModel(dataManager: dataManager)

        resultsViewModel = ResultsViewModel(dataManager: dataManager,
                                            notificationCenter: notificationCenter)

        containerViewModel = ContainerViewModel(scheduler: scheduler,
                                                dataManager: dataManager)

        dataManager.fetchProfile(ignoresCache: true)

        super.init(nibName: nil, bundle: nil)
    }

    private func setupNotifications() {
        notificationCenter.addObserver(self,
                                       selector: #selector(reloadData),
                                       name: DataBrokerProtectionNotifications.didFinishScan,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(reloadData),
                                       name: DataBrokerProtectionNotifications.didFinishOptOut,
                                       object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
//        let containerView = DataBrokerProtectionContainerView(
//            containerViewModel: containerViewModel,
//            navigationViewModel: navigationViewModel,
//            profileViewModel: profileViewModel,
//            resultsViewModel: resultsViewModel)
//
//        let hostingController = NSHostingController(rootView: containerView)
//        view = hostingController.view

        guard let privacyConfig = privacyConfig else { return }
        guard let prefs = prefs else { return }

        let configuration = WKWebViewConfiguration()
        configuration.applyDBPUIConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: dataManager.cache)
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let dbpUIContentController = configuration.userContentController as? DBPUIUserContentController {
            communicationLayer = dbpUIContentController.dbpUIUserScripts.dbpUICommunicationLayer
        }

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        view = webView!

        // FOR LOCAL WEB UI DEVELOPMENT:
        // Comment this line 👇
        webView?.loadHTMLString(debugPage, baseURL: nil)
        // Uncomment this line and add your dev URL 👇
//        webView?.load(URL(string: "https://<your url>")!)

        let button = NSButton(title: "Set State", target: self, action: #selector(reloadData))
        button.setButtonType(.momentaryLight)
        button.contentTintColor = .black
        button.frame = CGRect(x: 10, y: 100, width: 100, height: 50)
        view.addSubview(button)
    }

    @objc func reloadData() {
        guard let webView = webView else { return }

        Task {
            var inProgress: [DBPUIDataBrokerProfileMatch] = []
            var completed: [DBPUIDataBrokerProfileMatch] = []
            // Step 1 - Get Data from database (brokerInfo)
            let brokerInfoData = await dataManager.fetchBrokerProfileQueryData(ignoresCache: true)

            // Step 3 - For profileQueryData in brokerInfo
            for profileQueryData in brokerInfoData {
                // Step 3a - For optOut in profileQueryData
                for optOutOperationData in profileQueryData.optOutOperationsData {
                    // if optOut.extractedProfile.removedData == nil
                    if optOutOperationData.extractedProfile.removedDate == nil {
                        // Add as a pending removal profile
                        inProgress.append(DBPUIDataBrokerProfileMatch(
                            dataBroker: DBPUIDataBroker(name: profileQueryData.dataBroker.name),
                            names: [DBPUIUserProfileName(first: optOutOperationData.extractedProfile.fullName ?? "", middle: "", last: "")],
                            addresses: optOutOperationData.extractedProfile.addresses?.map {
                                DBPUIUserProfileAddress(street: $0.fullAddress, city: $0.city, state: $0.state)
                            } ?? []
                        ))
                    } else {
                        // else add as removed profile
                        completed.append(DBPUIDataBrokerProfileMatch(
                            dataBroker: DBPUIDataBroker(name: profileQueryData.dataBroker.name),
                            names: [DBPUIUserProfileName(first: optOutOperationData.extractedProfile.fullName ?? "", middle: "", last: "")],
                            addresses: optOutOperationData.extractedProfile.addresses?.map {
                                DBPUIUserProfileAddress(street: $0.fullAddress, city: $0.city, state: $0.state)
                            } ?? []
                        ))
                    }
                }
            }

            let message = DBPUIScanAndOptOutState(
                status: .removingProfile,
                inProgressOptOuts: inProgress,
                completedOptOuts: completed
            )

            communicationLayer?.sendMessageToUI(method: .scanAndOptOutStatusChanged, params: message, into: webView)
        }
    }

}
