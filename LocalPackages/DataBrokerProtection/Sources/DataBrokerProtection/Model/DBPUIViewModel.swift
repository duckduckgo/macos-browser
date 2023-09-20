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

import Foundation
import Combine
import WebKit
import BrowserServicesKit

protocol DBPUIScanOps: AnyObject {
    func startScan() -> Bool
}

final class DBPUIViewModel {
    private let dataManager: DataBrokerProtectionDataManaging
    private let scheduler: DataBrokerProtectionScheduler
    private let notificationCenter: NotificationCenter

    private let privacyConfig: PrivacyConfigurationManaging?
    private let prefs: ContentScopeProperties?
    private var communicationLayer: DBPUICommunicationLayer?
    private var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var lastSchedulerStatus: DataBrokerProtectionSchedulerStatus = .idle

    init(dataManager: DataBrokerProtectionDataManaging, scheduler: DataBrokerProtectionScheduler,
         notificationCenter: NotificationCenter = .default, privacyConfig: PrivacyConfigurationManaging? = nil,
         prefs: ContentScopeProperties? = nil, webView: WKWebView? = nil) {
        self.dataManager = dataManager
        self.scheduler = scheduler
        self.notificationCenter = notificationCenter
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.webView = webView

        setupNotifications()
        setupCancellable()
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

    private func setupCancellable() {
        scheduler.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.lastSchedulerStatus = status
                self?.reloadData()
            }.store(in: &cancellables)
    }

    @MainActor func setupCommunicationLayer() -> WKWebViewConfiguration? {
        guard let privacyConfig = privacyConfig else { return nil }
        guard let prefs = prefs else { return nil }

        let configuration = WKWebViewConfiguration()
        configuration.applyDBPUIConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: dataManager.cache)
        dataManager.cache.scanDelegate = self
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let dbpUIContentController = configuration.userContentController as? DBPUIUserContentController {
            communicationLayer = dbpUIContentController.dbpUIUserScripts.dbpUICommunicationLayer
        }

        return configuration
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
                status: DBPUIScanAndOptOutStatus.from(schedulerStatus: lastSchedulerStatus),
                inProgressOptOuts: inProgress,
                completedOptOuts: completed
            )

            communicationLayer?.sendMessageToUI(method: .scanAndOptOutStatusChanged, params: message, into: webView)
        }
    }
}

extension DBPUIViewModel: DBPUIScanOps {
    func startScan() -> Bool {
        scheduler.scanAllBrokers()
        return true
    }
}
