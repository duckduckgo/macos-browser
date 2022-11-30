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

final class NetworkProtectionMenu: NSMenu {
    private var networkProtection: NetworkProtection

    // MARK: - Initialization

    init(networkProtection: NetworkProtection = NetworkProtection()) {
        self.networkProtection = networkProtection

        super.init(title: "Network Protection")

        setup()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Setup & Reloading

    private func setup() {
        Task {
            try await reload()

            networkProtection.onConnectionChange = { [weak self] change in
                switch change {
                case .configuration:
                    print("configuration!")
                case .status(let newStatus):
                    print("status! \(newStatus)")
                }

                guard let self = self else {
                    return
                }
                
                Task {
                    try await self.reload()
                }
            }
        }
    }

    /// Reloads the full menu.
    ///
    @MainActor
    func reload() async throws {
        removeAllItems()

        let menuItem: NSMenuItem

        if try await networkProtection.isConnected() {
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

        items = [menuItem]
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
                // TODO: replace with proper logging or UI error handling
                print("🔴 Error starting the VPN tunnel: \(error)")
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
                // TODO: replace with proper logging or UI error handling
                print("🔴 Error stopping the VPN tunnel: \(error)")
            }
        }
    }
}
