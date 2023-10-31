//
//  DataBrokerProtectionLoginItemScheduler.swift
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
import DataBrokerProtection

/// A scheduler that launches a login item and the communicates with it through an IPC scheduler.
///
final class DataBrokerProtectionLoginItemScheduler {
    private let ipcScheduler: DataBrokerProtectionIPCScheduler
    private let loginItemsManager: LoginItemsManager

    init(ipcScheduler: DataBrokerProtectionIPCScheduler, loginItemsManager: LoginItemsManager = .init()) {
        self.ipcScheduler = ipcScheduler
        self.loginItemsManager = loginItemsManager
    }

    // MARK: - Login Item Management

    func disableLoginItem() {
        loginItemsManager.disableLoginItems([.dbpBackgroundAgent])
    }

    func enableLoginItem() {
        loginItemsManager.enableLoginItems([.dbpBackgroundAgent], log: .dbp)
    }
}

extension DataBrokerProtectionLoginItemScheduler: DataBrokerProtectionScheduler {
    var status: DataBrokerProtection.DataBrokerProtectionSchedulerStatus {
        ipcScheduler.status
    }

    var statusPublisher: Published<DataBrokerProtection.DataBrokerProtectionSchedulerStatus>.Publisher {
        ipcScheduler.statusPublisher
    }

    func scanAllBrokers(showWebView: Bool, completion: ((Error?) -> Void)?) {
        enableLoginItem()
        ipcScheduler.scanAllBrokers(showWebView: showWebView, completion: completion)
    }

    func startScheduler(showWebView: Bool) {
        enableLoginItem()
        ipcScheduler.startScheduler(showWebView: showWebView)
    }

    func stopScheduler() {
        ipcScheduler.stopScheduler()
    }

    func optOutAllBrokers(showWebView: Bool, completion: ((Error?) -> Void)?) {
        ipcScheduler.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    func runAllOperations(showWebView: Bool) {
        ipcScheduler.runAllOperations(showWebView: showWebView)
    }

    func runQueuedOperations(showWebView: Bool, completion: ((Error?) -> Void)?) {
        ipcScheduler.runQueuedOperations(showWebView: showWebView, completion: completion)
    }
}
