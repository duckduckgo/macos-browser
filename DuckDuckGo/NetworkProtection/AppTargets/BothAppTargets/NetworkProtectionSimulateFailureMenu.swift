//
//  NetworkProtectionSimulateFailureMenu.swift
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

import AppKit
import Foundation
import NetworkProtection
import SwiftUI

/// Implements the logic for the VPN's simulate failures menu.
///
final class NetworkProtectionSimulateFailureMenu: NSMenu {

    private let simulateControllerFailureMenuItem = NSMenuItem(title: "Enable NetP Controller Failure",
                                                               action: #selector(NetworkProtectionSimulateFailureMenu.simulateControllerFailure))
    private let simulateTunnelFailureMenuItem = NSMenuItem(title: "Tunnel Failure",
                                                           action: #selector(NetworkProtectionSimulateFailureMenu.simulateTunnelFailure))
    private let simulateTunnelCrashMenuItem = NSMenuItem(title: "Tunnel Crash",
                                                         action: #selector(NetworkProtectionSimulateFailureMenu.simulateTunnelCrash))
    private let simulateConnectionInterruptionMenuItem = NSMenuItem(title: "Connection Interruption",
                                                                    action: #selector(NetworkProtectionSimulateFailureMenu.simulateConnectionInterruption))

    init() {
        super.init(title: "")
        buildItems {
            simulateControllerFailureMenuItem.targetting(self)
            simulateTunnelFailureMenuItem.targetting(self)
            simulateTunnelCrashMenuItem.targetting(self)
            simulateConnectionInterruptionMenuItem.targetting(self)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var simulationOptions: NetworkProtectionSimulationOptions {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        NetworkProtectionSimulationOptions()
    }

    /// Simulates a controller failure the next time the VPN is started.
    ///
    @objc func simulateControllerFailure(_ menuItem: NSMenuItem) {
        simulationOptions.setEnabled(menuItem.state == .off, option: .controllerFailure)
    }

    /// Simulates a tunnel failure the next time the VPN is started.
    ///
    @objc func simulateTunnelFailure(_ menuItem: NSMenuItem) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        // simulateFailure(NetworkProtectionTunnelController().toggleShouldSimulateTunnelFailure)
    }

    /// Simulates a fatal error on the tunnel the next time the VPN is started.
    ///
    @objc func simulateTunnelCrash(_ menuItem: NSMenuItem) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        // simulateFailure(NetworkProtectionTunnelController().toggleShouldSimulateTunnelFatalError)
    }

    @objc func simulateConnectionInterruption(_ menuItem: NSMenuItem) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        // simulateFailure(NetworkProtectionTunnelController().toggleShouldSimulateConnectionInterruption)
    }

    private func simulateFailure(_ simulationFunction: @escaping () async throws -> Void) {
        Task {
            do {
                try await simulationFunction()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    override func update() {
        simulateControllerFailureMenuItem.state = simulationOptions.isEnabled(.controllerFailure) ? .on : .off
        simulateTunnelFailureMenuItem.state = simulationOptions.isEnabled(.tunnelFailure) ? .on : .off
        simulateTunnelCrashMenuItem.state = simulationOptions.isEnabled(.crashFatalError) ? .on : .off
        simulateConnectionInterruptionMenuItem.state = simulationOptions.isEnabled(.connectionInterruption) ? .on : .off
    }
}
