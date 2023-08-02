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

import Foundation
import NetworkProtection

#if !NETWORK_PROTECTION

@objc
final class NetworkProtectionSimulateFailureMenu: NSMenu {
}

#else

/// Implements the logic for Network Protection's simulate failures menu.
///
@available(macOS 11.4, *)
@objc
@MainActor
final class NetworkProtectionSimulateFailureMenu: NSMenu {
    @IBOutlet weak var simulateControllerFailureMenuItem: NSMenuItem!
    @IBOutlet weak var simulateTunnelFailureMenuItem: NSMenuItem!

    private var simulationOptions: NetworkProtectionSimulationOptions {
        NetworkProtectionTunnelController.simulationOptions
    }

    /// Simulates a controller failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateControllerFailure(_ menuItem: NSMenuItem) {
        simulationOptions.setEnabled(menuItem.state == .off, option: .controllerFailure)
    }

    /// Simulates a tunnel failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateTunnelFailure(_ menuItem: NSMenuItem) {
        Task {
            do {
                try await NetworkProtectionTunnelController().toggleShouldSimulateTunnelFailure()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    override func update() {
        simulateControllerFailureMenuItem.state = simulationOptions.isEnabled(.controllerFailure) ? .on : .off
        simulateTunnelFailureMenuItem.state = simulationOptions.isEnabled(.tunnelFailure) ? .on : .off
    }
}

#endif
