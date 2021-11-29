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
import WebKit

protocol PermissionContextMenuDelegate: AnyObject {
    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, revokePermissions: [PermissionType])
    func permissionContextMenu(_ menu: PermissionContextMenu, allowPermissionQuery: PermissionAuthorizationQuery)
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermission: PermissionType)
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermission: PermissionType)
    func permissionContextMenu(_ menu: PermissionContextMenu, resetStoredPermission: PermissionType)
    func permissionContextMenuReloadPage(_ menu: PermissionContextMenu)
}

final class PermissionContextMenu: NSMenu {

    let domain: String
    let permissions: [(key: PermissionType, value: PermissionState)]
    weak var actionDelegate: PermissionContextMenuDelegate?

    required init(coder: NSCoder) {
        fatalError("PermissionContextMenu: Bad initializer")
    }

    init(permissions: [(key: PermissionType, value: PermissionState)],
         domain: String,
         delegate: PermissionContextMenuDelegate?) {
        self.domain = domain.dropWWW()
        self.permissions = permissions
        self.actionDelegate = delegate
        super.init(title: "")

        setupMenuItems()
    }

    private func setupMenuItems() {
        let remainingPermission = setupCameraPermissionsMenuItems(permissions.reduce(into: Permissions()) {
            $0[$1.key] = $1.value
        })
        setupOtherPermissionMenuItems(for: remainingPermission)
        addRevokeItems()
        addPersistenceItems()
        setupPopupsPermissionsMenuItems()
    }

    private func setupCameraPermissionsMenuItems(_ permissions: Permissions) -> Permissions {
        var permissions = permissions
        let permissionTypes = permissions.keys.sorted(by: { lhs, _ in lhs == .camera })

        switch permissions.camera {
        case .active:
            if ![.active, .inactive].contains(permissions.microphone) || WKWebView.canMuteCameraAndMicrophoneSeparately {
                addItem(.mute([.camera], target: self))
            } else {
                addItem(.mute(permissionTypes, target: self))
                permissions.microphone = nil
            }
            permissions.camera = nil

        case .paused:
            if permissions.microphone != .paused || WKWebView.canMuteCameraAndMicrophoneSeparately {
                addItem(.unmute([.camera], target: self))
            } else {
                addItem(.unmute(permissionTypes, target: self))
                permissions.microphone = nil
            }
            permissions.camera = nil

        default:
            break
        }

        return permissions
    }

    private func setupOtherPermissionMenuItems(for permissions: Permissions) {
        let permanentlyDeniedPermission = permissions.first(where: {
            $0.value == .denied && PermissionManager.shared.permission(forDomain: domain, permissionType: $0.key) == false
        })
        // don't display Reload item for permanently denied Permissions
        var shouldAddReload = permanentlyDeniedPermission == nil
        for (idx, (permission, state)) in permissions.sorted(by: { lhs, _ in lhs.key == .camera }).enumerated() {
            switch state {
            case .active:
                addItem(.mute([permission], target: self))
            case .paused:
                addItem(.unmute([permission], target: self))
            case .inactive:
                break

            case .denied:
                guard shouldAddReload else { break }
                addItem(.reload(target: self))
                shouldAddReload = false

            case .disabled(systemWide: let systemWide):
                addSeparator(if: idx == 0 && numberOfItems > 0)
                addItem(.permissionDisabled(permission, systemWide: systemWide))
                addItem(.openSystemPreferences(for: permission, target: self))
                addSeparator(if: idx + 1 < permissions.count)

            case .revoking, .reloading:
                // expected permission to deactivate access
                return
            case .requested(_):
                return
            }
        }
    }

    private func setupPopupsPermissionsMenuItems() {
        var popupsItemsAdded = false
        for (permission, state) in permissions {
            guard case (.popups, .requested(let query)) = (permission, state) else { continue }

            if !popupsItemsAdded {
                addItem(.popupPermissionRequested(domain: domain))

                popupsItemsAdded = true
            }

            addItem(.openPopup(query: query, permission: permission, target: self))
        }
        guard popupsItemsAdded else { return }

        addItem(.separator())

        if PermissionManager.shared.permission(forDomain: domain, permissionType: .popups) == nil {
            addItem(.alwaysAllow(.popups, on: domain, target: self))
        } else {
            addItem(.alwaysAsk(.popups, on: domain, target: self))
        }
    }

    private func addRevokeItems() {
        guard permissions.contains(where: {
            [.active, .inactive, .paused].contains($0.value) && $0.key != .popups
        }) else { return }

        addSeparator(if: numberOfItems > 0)

        let permissionTypes = permissions.map(\.key).sorted(by: { lhs, _ in lhs == .camera })
        addItem(.revoke(permissionTypes, target: self))
    }

    private func addPersistenceItems() {
        addSeparator(if: numberOfItems > 0)

        for (permission, state) in permissions {
            switch state {
            case .active, .inactive, .paused:
                guard permission.canPersistGrantedDecision else { continue }
                if PermissionManager.shared.permission(forDomain: domain, permissionType: permission) == nil {
                    addItem(.alwaysAllow(permission, on: domain, target: self))
                } else {
                    addItem(.alwaysAsk(permission, on: domain, target: self))
                }

            case .denied:
                if PermissionManager.shared.permission(forDomain: domain, permissionType: permission) == nil {
                    addItem(.alwaysDeny(permission, on: domain, target: self))
                } else {
                    addItem(.alwaysAsk(permission, on: domain, target: self))
                }

            case .revoking, .requested, .disabled, .reloading: break
            }
        }
    }

    private func addSeparator(if condition: Bool) {
        if condition {
            addItem(.separator())
        }
    }

    @objc func mutePermissions(_ sender: NSMenuItem) {
        guard let permissions = sender.representedObject as? [PermissionType] else {
            assertionFailure("Expected [PermissionType]")
            return
        }
        actionDelegate?.permissionContextMenu(self, mutePermissions: permissions)
    }
    @objc func unmutePermissions(_ sender: NSMenuItem) {
        guard let permissions = sender.representedObject as? [PermissionType] else {
            assertionFailure("Expected [PermissionType]")
            return
        }
        actionDelegate?.permissionContextMenu(self, unmutePermissions: permissions)
    }
    @objc func revokePermissions(_ sender: NSMenuItem) {
        guard let permissions = sender.representedObject as? [PermissionType] else {
            assertionFailure("Expected [PermissionType]")
            return
        }
        actionDelegate?.permissionContextMenu(self, revokePermissions: permissions)
    }
    @objc func alwaysAllowPermission(_ sender: NSMenuItem) {
        guard let permission = sender.representedObject as? PermissionType else {
            assertionFailure("Expected PermissionType")
            return
        }
        actionDelegate?.permissionContextMenu(self, alwaysAllowPermission: permission)
    }
    @objc func alwaysAskPermission(_ sender: NSMenuItem) {
        guard let permission = sender.representedObject as? PermissionType else {
            assertionFailure("Expected PermissionType")
            return
        }
        actionDelegate?.permissionContextMenu(self, resetStoredPermission: permission)
    }
    @objc func alwaysDenyPermission(_ sender: NSMenuItem) {
        guard let permission = sender.representedObject as? PermissionType else {
            assertionFailure("Expected PermissionType")
            return
        }
        actionDelegate?.permissionContextMenu(self, alwaysDenyPermission: permission)
    }
    @objc func reload(_ sender: NSMenuItem) {
        actionDelegate?.permissionContextMenuReloadPage(self)
    }

    @objc func openPopup(_ sender: NSMenuItem) {
        guard let query = sender.representedObject as? PermissionAuthorizationQuery else {
            assertionFailure("Expected PermissionAuthorizationQuery")
            return
        }
        actionDelegate?.permissionContextMenu(self, allowPermissionQuery: query)
    }

    @objc func openSystemPreferences(_ sender: NSMenuItem) {
        guard let permission = sender.representedObject as? PermissionType else {
            assertionFailure("Expected PermissionType")
            return
        }

        let deeplink: URL
        switch permission {
        case .camera:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        case .microphone:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .geolocation:
            deeplink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        case .popups:
            assertionFailure("No settings available for Popups")
            return
        }
        NSWorkspace.shared.open(deeplink)
    }

}

private extension NSMenuItem {

    static func mute(_ permissions: [PermissionType], target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionMuteFormat, permissions.localizedDescription)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.mutePermissions),
                              keyEquivalent: "")
        item.representedObject = permissions
        item.target = target
        return item
    }

    static func unmute(_ permissions: [PermissionType], target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionUnmuteFormat, permissions.localizedDescription)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.unmutePermissions),
                              keyEquivalent: "")
        item.representedObject = permissions
        item.target = target
        return item
    }

    static func revoke(_ permissions: [PermissionType], target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionRevokeFormat, permissions.localizedDescription)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.revokePermissions),
                              keyEquivalent: "")
        item.representedObject = permissions
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
        item.representedObject = permission
        item.target = target
        return item
    }

    static func alwaysAsk(_ permission: PermissionType, on domain: String, target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionAlwaysAskDeviceFormat, permission.localizedDescription, domain)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.alwaysAskPermission),
                              keyEquivalent: "")
        item.representedObject = permission
        item.target = target
        return item
    }

    static func alwaysDeny(_ permission: PermissionType, on domain: String, target: PermissionContextMenu) -> NSMenuItem {
        let title = String(format: UserText.permissionAlwaysDenyDeviceFormat, permission.localizedDescription, domain)
        let item = NSMenuItem(title: title,
                              action: #selector(PermissionContextMenu.alwaysDenyPermission),
                              keyEquivalent: "")
        item.representedObject = permission
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

    static func openSystemPreferences(for permission: PermissionType, target: PermissionContextMenu) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.permissionOpenSystemPreferences,
                              action: #selector(PermissionContextMenu.openSystemPreferences),
                              keyEquivalent: "")
        item.representedObject = permission
        item.target = target
        return item
    }

    static func popupPermissionRequested(domain: String?) -> NSMenuItem {
        let title = String(format: UserText.permissionPopupTitleFormat, domain ?? "“”")
        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.setAttributes([.font: NSFont.systemFont(ofSize: 11.0)], range: title.nsRange())

        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menuItem.attributedTitle = attributedTitle

        return menuItem
    }

    static func openPopup(query: PermissionAuthorizationQuery,
                          permission: PermissionType,
                          target: PermissionContextMenu) -> NSMenuItem {

        let title = String(format: UserText.permissionPopupOpenFormat, query.url?.absoluteString ?? "“”")
        let item = NSMenuItem(title: title, action: #selector(PermissionContextMenu.openPopup), keyEquivalent: "")
        item.representedObject = query
        item.target = target
        return item
    }

}
