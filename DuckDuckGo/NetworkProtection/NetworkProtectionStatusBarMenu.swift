//
//  NetworkProtectionStatusBarMenu.swift
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

/// Abstraction to abstract the logic needed to interact with the Network Protection status bar menu.
///
final class NetworkProtectionStatusBarMenu {
    private let statusItem: NSStatusItem

    // MARK: - Initialization

    init(networkProtection: NetworkProtection, statusItem: NSStatusItem? = nil) {
        self.statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.menu = NetworkProtectionMenu(networkProtection: networkProtection)
        self.statusItem.button?.image = .NetworkProtection.statusBarMenuIcon
        self.statusItem.isVisible = false
    }

    // MARK: - Showing & Hiding the menu

    func show() {
        statusItem.isVisible = true
    }

    func hide() {
        statusItem.isVisible = false
    }
}
