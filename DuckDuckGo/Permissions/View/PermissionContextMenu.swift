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
    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, resetStoredPermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, reloadPageForPermissions: [PermissionType])
}

final class PermissionContextMenu: NSMenu {

    let domain: String
    let permissions: [PermissionType]
    weak var actionDelegate: PermissionContextMenuDelegate?

    required init(coder: NSCoder) {
        fatalError("PermissionContextMenu: Bad initializer")
    }

    init(permissions: [PermissionType], state: PermissionState, domain: String, delegate: PermissionContextMenuDelegate?) {
        self.domain = domain.dropWWW()
        self.permissions = permissions
        self.actionDelegate = delegate
        super.init(title: "")

        setupMenuItems(state: state)
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    private func setupMenuItems(state: PermissionState) {
        switch state {
        case .active, .inactive:
            if permissions.contains(.camera) && permissions.contains(.microphone),
               WKWebView.canMuteCameraAndMicrophoneSeparately {
                addItem(.mute([.camera], target: self))
                addItem(.mute([.microphone], target: self))
            } else {
                addItem(.mute(permissions, target: self))
            }
            addItem(.separator())

            for permission in permissions {
                if PermissionManager.shared.permission(forDomain: domain, permissionType: permission) == nil {
                    addItem(.alwaysAllow(permission, on: domain, target: self))
                } else {
                    addItem(.alwaysAsk(permission, on: domain, target: self))
                }
            }

        case .paused:
            if permissions.contains(.camera) && permissions.contains(.microphone),
               WKWebView.canMuteCameraAndMicrophoneSeparately {
                addItem(.unmute([.camera], target: self))
                addItem(.unmute([.microphone], target: self))
            } else {
                addItem(.unmute(permissions, target: self))
            }
            addItem(NSMenuItem.separator())

            for permission in permissions {
                if PermissionManager.shared.permission(forDomain: domain, permissionType: permission) == nil {
                    addItem(.alwaysAllow(permission, on: domain, target: self))
                } else {
                    addItem(.alwaysAsk(permission, on: domain, target: self))
                }
            }

        case .denied:
            addItem(.reload(target: self))
            addItem(NSMenuItem.separator())

            for permission in permissions {
                if PermissionManager.shared.permission(forDomain: domain, permissionType: permission) == nil {
                    addItem(.alwaysDeny(permission, on: domain, target: self))
                } else {
                    addItem(.alwaysAsk(permission, on: domain, target: self))
                }
            }

        case .disabled(systemWide: let systemWide):
            guard let permission = permissions.first else {
                assertionFailure("Permissions expected")
                return
            }
            addItem(.permissionDisabled(permission, systemWide: systemWide))
            addItem(.openSystemPreferences(target: self))

        case .revoking:
            // expected permission to deactivate access
            return
        case .requested(_):
            // popover should be shown
            return
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    @objc func mutePermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, mutePermissions: permissions)
    }
    @objc func unmutePermission(_ sender: NSMenuItem) {
        print("unmutePermission:")
        actionDelegate?.permissionContextMenu(self, unmutePermissions: permissions)
    }
    @objc func alwaysAllowPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, alwaysAllowPermissions: permissions)
    }
    @objc func alwaysAskPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, resetStoredPermissions: permissions)
    }
    @objc func alwaysDenyPermission(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, alwaysDenyPermissions: permissions)
    }
    @objc func reload(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenu(self, reloadPageForPermissions: permissions)
    }

    @objc func openSystemPreferences(_ sender: NSMenuItem) {
        let deeplink: URL
        switch permissions.first {
        case .camera:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        case .microphone:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .geolocation:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        case .none:
            assertionFailure("Permissions expected")
            return
        }
        NSWorkspace.shared.open(deeplink)
    }

}

private extension NSMenuItem {

    static func mute(_ permissions: [PermissionType], target: PermissionContextMenu) -> NSMenuItem {
        let localizedPermissions = permissions.map(\.localizedDescription).reduce("") {
            $0.isEmpty ? $1 : String(format: UserText.permissionAndPermissionFormat, $0, $1)
        }
        let title = String(format: UserText.permissionMuteFormat, localizedPermissions)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.mutePermission),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func unmute(_ permissions: [PermissionType], target: PermissionContextMenu) -> NSMenuItem {
        let localizedPermissions = permissions.map(\.localizedDescription).reduce("") {
            $0.isEmpty ? $1 : String(format: UserText.permissionAndPermissionFormat, $0, $1)
        }
        let title = String(format: UserText.permissionUnmuteFormat, localizedPermissions)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.unmutePermission),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func reload(target: PermissionContextMenu) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.permissionReloadToEnable,
                              action: #selector(PermissionContextMenu.reload),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func alwaysAllow(_ permission: PermissionType, on domain: String, target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionAlwaysAllowDeviceFormat, permission.localizedDescription, domain)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.alwaysAllowPermission),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func alwaysAsk(_ permission: PermissionType, on domain: String, target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionAlwaysAskDeviceFormat, permission.localizedDescription, domain)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.alwaysAskPermission),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func alwaysDeny(_ permission: PermissionType, on domain: String, target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionAlwaysDenyDeviceFormat, permission.localizedDescription, domain)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.alwaysDenyPermission),
                              keyEquivalent: "")
        item.target = target
        return item
    }

    static func permissionDisabled(_ permission: PermissionType, systemWide: Bool) -> NSMenuItem {
        let title: String
        if systemWide {
            assert(permission == .geolocation)
            title = UserText.permissionGeolocationServicesDisabled
        } else {
            title = String(format: UserText.permissionAppPermissionDisabledFormat,
                           Bundle.main.displayName,
                           permission.localizedDescription)
        }
        return NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    static func openSystemPreferences(target: PermissionContextMenu) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.permissionOpenSystemPreferences,
                              action: #selector(PermissionContextMenu.openSystemPreferences),
                              keyEquivalent: "")
        item.target = target
        return item
    }

}
