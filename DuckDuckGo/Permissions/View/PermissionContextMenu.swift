//
//  PermissionContextMenu.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Cocoa

protocol PermissionContextMenuDelegate: AnyObject {
    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermission: PermissionType)
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermission: PermissionType)
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermission: PermissionType)
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermission: PermissionType)
    func permissionContextMenuResetStoredPermission(_ menu: PermissionContextMenu)
    func permissionContextMenu(_ menu: PermissionContextMenu, reloadPageForPermission: PermissionType)
}

final class PermissionContextMenu: NSMenu {

    let domain: String
    let permissionType: PermissionType
    weak var actionDelegate: PermissionContextMenuDelegate?

    required init(coder: NSCoder) {
        fatalError("PermissionContextMenu: Bad initializer")
    }

    init(permissionType: PermissionType, state: PermissionState?, domain: String, delegate: PermissionContextMenuDelegate?) {
        self.domain = domain.dropWWW()
        self.permissionType = permissionType
        self.actionDelegate = delegate
        super.init(title: "")

        setupMenuItems(state: state)
    }

    // swiftlint:disable function_body_length
    private func setupMenuItems(state: PermissionState?) {
        switch state {
        case .some(.active):
            let muteMenuItem = NSMenuItem(title: UserText.permissionMute,
                                             action: #selector(mutePermission),
                                             keyEquivalent: "")
            muteMenuItem.target = self
            addItem(muteMenuItem)

            addItem(NSMenuItem.separator())

            let alwaysItem: NSMenuItem
            if PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType) == nil {
                let title = String(format: UserText.permissionAlwaysAllowFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysAllowPermission),
                                        keyEquivalent: "")
            } else {
                let title = String(format: UserText.permissionAlwaysAskFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysAskPermission),
                                        keyEquivalent: "")
            }
            alwaysItem.target = self
            addItem(alwaysItem)

        case .some(.paused):
            print("paused state")
            let unmuteMenuItem = NSMenuItem(title: UserText.permissionUnmute,
                                             action: #selector(unmutePermission),
                                             keyEquivalent: "")
            unmuteMenuItem.target = self
            addItem(unmuteMenuItem)

            addItem(NSMenuItem.separator())

            let alwaysItem: NSMenuItem
            if PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType) == nil {
                let title = String(format: UserText.permissionAlwaysAllowFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysAllowPermission),
                                        keyEquivalent: "")
            } else {
                let title = String(format: UserText.permissionAlwaysAskFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysAskPermission),
                                        keyEquivalent: "")
            }
            alwaysItem.target = self
            addItem(alwaysItem)

        case .none:
            let reloadMenuItem = NSMenuItem(title: UserText.permissionReloadToEnable,
                                             action: #selector(reload),
                                             keyEquivalent: "")
            reloadMenuItem.target = self
            addItem(reloadMenuItem)

            addItem(NSMenuItem.separator())

            let alwaysItem: NSMenuItem
            if PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType) == nil {
                let title = String(format: UserText.permissionAlwaysDenyFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysDenyPermission),
                                        keyEquivalent: "")
            } else {
                let title = String(format: UserText.permissionAlwaysAskFormat, domain)
                alwaysItem = NSMenuItem(title: title,
                                        action: #selector(alwaysAskPermission),
                                        keyEquivalent: "")
            }
            alwaysItem.target = self
            addItem(alwaysItem)
        }
    }
    // swiftlint:enable function_body_length

    @objc func mutePermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, mutePermission: permissionType)
    }
    @objc func unmutePermission(_ sender: NSMenuItem) {
        print("unmutePermission:")
        actionDelegate?.permissionContextMenu(self, unmutePermission: permissionType)
    }
    @objc func alwaysAllowPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, alwaysAllowPermission: permissionType)
    }
    @objc func alwaysAskPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenuResetStoredPermission(self)
    }
    @objc func alwaysDenyPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, alwaysDenyPermission: permissionType)
    }
    @objc func reload(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, reloadPageForPermission: permissionType)
    }

}
