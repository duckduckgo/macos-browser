//
//  NetworkProtectionConnectionTesterMenu.swift
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
import Common
import Foundation
import NetworkProtection

/// The model that handles the logic for the debug menu.
///
public protocol ConnectionTesterMenuModel {
    /// Whether the connection tester should use its new behavior
    ///
    var useNewConnectionTesterBehavior: Bool { get set }

    /// Resets all settings to their default values
    ///
    func resetToDefaults()
}

/// Controller for the Network Protection debug menu.
///
@objc
@MainActor
public final class ConnectionTesterMenu: NSMenu {

    private var model: ConnectionTesterMenuModel

    private let resetToDefaultsMenuItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetToDefaults), keyEquivalent: "")
    private var useNewConnectionTesterBehaviorMenuItem = NSMenuItem(title: "Use new proposed behavior", action: #selector(toggleUseNewConnectionTesterBehavior), keyEquivalent: "")

    public init(title: String, model: ConnectionTesterMenuModel) {
        self.model = model

        super.init(title: title)

        autoenablesItems = true
        resetToDefaultsMenuItem.target = self
        useNewConnectionTesterBehaviorMenuItem.target = self

        addItem(resetToDefaultsMenuItem)
        addItem(.separator())
        addItem(useNewConnectionTesterBehaviorMenuItem)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func resetToDefaults() {
        model.resetToDefaults()
    }

    @objc
    func toggleUseNewConnectionTesterBehavior() {
        model.useNewConnectionTesterBehavior.toggle()
    }

    // MARK: - Menu State Update

    public override func update() {
        useNewConnectionTesterBehaviorMenuItem.state = model.useNewConnectionTesterBehavior ? .on : .off
    }
}
/*
extension NetworkProtectionDebugMenu: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === exclusionsMenu {
            let controller = NetworkProtectionTunnelController()
            for item in menu.items {
                guard let route = item.representedObject as? String else { continue }
                item.state = controller.isExcludedRouteEnabled(route) ? .on : .off
                // TO BE fixed: see NetworkProtectionTunnelController.excludedRoutes()
                item.isEnabled = !(controller.shouldEnforceRoutes && route == "10.0.0.0/8")
            }
        }
    }

}*/
