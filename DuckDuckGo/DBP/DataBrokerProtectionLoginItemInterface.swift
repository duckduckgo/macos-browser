//
//  DataBrokerProtectionLoginItemInterface.swift
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

#if DBP

import Foundation
import DataBrokerProtection
import Common

protocol DataBrokerProtectionLoginItemInterface: DataBrokerProtectionAgentInterface {
    func disableLoginItem()
    func enableLoginItem()
}

/// Launches a login item and then communicates with it through IPC
///
final class DefaultDataBrokerProtectionLoginItemInterface {
    private let ipcClient: DataBrokerProtectionIPCClient
    private let loginItemsManager: LoginItemsManager

    init(ipcClient: DataBrokerProtectionIPCClient, loginItemsManager: LoginItemsManager = .init()) {
        self.ipcClient = ipcClient
        self.loginItemsManager = loginItemsManager
    }
}

extension DefaultDataBrokerProtectionLoginItemInterface: DataBrokerProtectionLoginItemInterface {

    // MARK: - Login Item Management

    func disableLoginItem() {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerDisableLoginItemDaily, frequency: .daily)
        loginItemsManager.disableLoginItems([.dbpBackgroundAgent])
    }

    func enableLoginItem() {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerEnableLoginItemDaily, frequency: .daily)
        loginItemsManager.enableLoginItems([.dbpBackgroundAgent], log: .dbp)
    }

    // MARK: - DataBrokerProtectionAgentInterface
    // MARK: - DataBrokerProtectionAgentAppEvents

    func profileSaved() {
        enableLoginItem()
        ipcClient.profileSaved { error in
            // TODO
        }
    }

    func dataDeleted() {
        ipcClient.dataDeleted { error in
            // TODO
        }
    }

    func appLaunched() {
        ipcClient.appLaunched { error in
            // TODO
        }
    }

    // MARK: - DataBrokerProtectionAgentDebugCommands

    func openBrowser(domain: String) {
        ipcClient.openBrowser(domain: domain)
    }

    func startManualScan(showWebView: Bool) {
        ipcClient.startManualScan(showWebView: showWebView)
    }

    func runQueuedOperations(showWebView: Bool) {
        ipcClient.runQueuedOperations(showWebView: showWebView)
    }

    func runAllOptOuts(showWebView: Bool) {
        ipcClient.runAllOptOuts(showWebView: showWebView)
    }

    func getDebugMetadata() async -> DataBrokerProtection.DBPBackgroundAgentMetadata? {
        return await ipcClient.getDebugMetadata()
    }
}

#endif
