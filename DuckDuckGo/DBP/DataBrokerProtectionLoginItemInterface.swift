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

import Foundation
import DataBrokerProtection
import Common

protocol DataBrokerProtectionLoginItemInterface: DataBrokerProtectionAppToAgentInterface {
    func dataDeleted()
}

/// Launches a login item and then communicates with it through IPC
///
final class DefaultDataBrokerProtectionLoginItemInterface {
    private let ipcClient: DataBrokerProtectionIPCClient
    private let loginItemsManager: LoginItemsManager
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    init(ipcClient: DataBrokerProtectionIPCClient,
         loginItemsManager: LoginItemsManager = .init(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.ipcClient = ipcClient
        self.loginItemsManager = loginItemsManager
        self.pixelHandler = pixelHandler
    }
}

extension DefaultDataBrokerProtectionLoginItemInterface: DataBrokerProtectionLoginItemInterface {

    // MARK: - Login Item Management

    private func disableLoginItem() {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerDisableLoginItemDaily, frequency: .daily)
        loginItemsManager.disableLoginItems([.dbpBackgroundAgent])
    }

    private func enableLoginItem() {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerEnableLoginItemDaily, frequency: .daily)
        loginItemsManager.enableLoginItems([.dbpBackgroundAgent])
    }

    // MARK: - DataBrokerProtectionLoginItemInterface

    func dataDeleted() {
        disableLoginItem()
    }

    // MARK: - DataBrokerProtectionAppToAgentInterface
    // MARK: - DataBrokerProtectionAgentAppEvents

    func profileSaved() {
        enableLoginItem()

        Task {
            // Wait to make sure the agent has had time to launch
            try await Task.sleep(nanoseconds: 1_000_000_000)
            pixelHandler.fire(.ipcServerProfileSavedCalledByApp)
            ipcClient.profileSaved { error in
                if let error = error {
                    self.pixelHandler.fire(.ipcServerProfileSavedXPCError(error: error))
                } else {
                    self.pixelHandler.fire(.ipcServerProfileSavedReceivedByAgent)
                }
            }
        }
    }

    func appLaunched() {
        pixelHandler.fire(.ipcServerAppLaunchedCalledByApp)
        ipcClient.appLaunched { error in
            if let error = error {
                self.pixelHandler.fire(.ipcServerAppLaunchedXPCError(error: error))
            } else {
                self.pixelHandler.fire(.ipcServerAppLaunchedReceivedByAgent)
            }
        }
    }

    // MARK: - DataBrokerProtectionAgentDebugCommands

    func openBrowser(domain: String) {
        ipcClient.openBrowser(domain: domain)
    }

    func startImmediateOperations(showWebView: Bool) {
        ipcClient.startImmediateOperations(showWebView: showWebView)
    }

    func startScheduledOperations(showWebView: Bool) {
        ipcClient.startScheduledOperations(showWebView: showWebView)
    }

    func runAllOptOuts(showWebView: Bool) {
        ipcClient.runAllOptOuts(showWebView: showWebView)
    }

    func getDebugMetadata() async -> DataBrokerProtection.DBPBackgroundAgentMetadata? {
        return await ipcClient.getDebugMetadata()
    }
}
