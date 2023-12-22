//
//  StatusBarMenuModel.swift
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

public final class StatusBarMenuModel {
    private let vpnSettings: VPNSettings

    public init(vpnSettings: VPNSettings) {
        self.vpnSettings = vpnSettings
    }

    var hideVPNMenu: NSMenuItem {
        let item = NSMenuItem(title: "Don’t Show VPN in Menu Bar", action: #selector(hideVPNMenuItemAction), keyEquivalent: "")
        item.target = self
        return item
    }

    var contextMenuItems: [NSMenuItem] {
        [
            hideVPNMenu
        ]
    }

    @objc
    private func hideVPNMenuItemAction() {
        vpnSettings.showInMenuBar = false
    }
}
