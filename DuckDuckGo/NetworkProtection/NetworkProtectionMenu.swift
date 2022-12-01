//
//  NetworkProtectionMenu.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

protocol NetworkProtectionMenuProtocol: NSMenu {}

/// The network protection menu.  This is mostly intended to be shown in the status bar, but was designed to be reusable in case
/// we want to show this menu elsewhere.
///
final class NetworkProtectionMenu: NSMenu, NetworkProtectionMenuProtocol {
    private var networkProtection: NetworkProtection
    private let logger: NetworkProtectionLogger

    // MARK: - Initialization

    init(networkProtection: NetworkProtection = NetworkProtection(),
         logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.logger = logger
        self.networkProtection = networkProtection

        super.init(title: "Network Protection")

        setup()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Setup & Reloading

    private func setup() {
        reload()

        networkProtection.onStatusChange = { [weak self] _ in
            guard let self = self else {
                return
            }

            self.reload()
        }
    }

    /// Reload using this method if the caller doesn't need to wait for completion.
    ///
    private func reload() {
        Task {
            await reload()
        }
    }

    /// Reloads the full menu.
    ///
    @MainActor
    private func reload() async {
        removeAllItems()

        let connectionMenuItem = await connectionMenuItem()

        items = [connectionMenuItem]
    }

    private func connectionMenuItem() async -> NSMenuItem {
        let menuItem: NSMenuItem
        let isConnected: Bool

        do {
            isConnected = try await networkProtection.isConnected()
        } catch {
            // We'll log an error but we'll also react as if the tunnel was not connected, so that users
            // can attempt to connect (and maybe who knows, make things work well again?), and not be completely
            // stuck by a non-working UI.
            logger.log(error)
            isConnected = false
        }

        if isConnected {
            menuItem = NSMenuItem()
            menuItem.title = "Stop Network Protection"
            menuItem.target = self
            menuItem.action = #selector(stopNetworkProtectionSelected)
        } else {
            menuItem = NSMenuItem()
            menuItem.title = "Start Network Protection"
            menuItem.target = self
            menuItem.action = #selector(startNetworkProtectionSelected)
        }

        return menuItem
    }

    // MARK: - Network Protection Interaction

    @objc
    private func startNetworkProtectionSelected() {
        Task {
            do {
                guard try await !networkProtection.isConnected() else {
                    return
                }

                try await networkProtection.start()
            } catch {
                logger.log(error)
            }
        }
    }

    @objc
    private func stopNetworkProtectionSelected() {
        Task {
            do {
                guard try await networkProtection.isConnected() else {
                    return
                }

                try await networkProtection.stop()
            } catch {
                logger.log(error)
            }
        }
    }
}
