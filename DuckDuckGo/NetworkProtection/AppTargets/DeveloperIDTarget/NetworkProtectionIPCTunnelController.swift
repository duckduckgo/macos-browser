//
//  NetworkProtectionIPCClient.swift
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
import NetworkProtection
import NetworkProtectionIPC

final class NetworkProtectionIPCTunnelController: TunnelController {

    private let loginItemsManager: LoginItemsManager
    private let ipcClient: TunnelControllerIPCClient

    init(loginItemsManager: LoginItemsManager = LoginItemsManager(),
         ipcClient: TunnelControllerIPCClient) {

        self.loginItemsManager = loginItemsManager
        self.ipcClient = ipcClient
    }

    func start() async {
        enableLoginItems()

        ipcClient.start()
    }

    func stop() async {
        enableLoginItems()

        ipcClient.stop()
    }

    // MARK: - Login Items Manager

    private func enableLoginItems() {
        loginItemsManager.enableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)
    }
}
