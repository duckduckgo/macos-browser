//
//  NavigationBarPopovers.swift
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
import BrowserServicesKit
import NetworkProtection
import NetworkProtectionUI
import AppKit

final class NavigationBarPopovers {

    enum Constants {
        static let downloadsPopoverAutoHidingInterval: TimeInterval = 10
    }

    private(set) var bookmarkListPopover: BookmarkListPopover?
    private(set) var saveCredentialsPopover: SaveCredentialsPopover?
    private(set) var saveIdentityPopover: SaveIdentityPopover?
    private(set) var savePaymentMethodPopover: SavePaymentMethodPopover?
    private(set) var passwordManagementPopover: PasswordManagementPopover?
    private(set) var downloadsPopover: DownloadsPopover?
    private(set) var networkProtectionPopover: NetworkProtectionPopover?

    var passwordManagementDomain: String? {
        didSet {
            passwordManagementPopover?.viewController.domain = passwordManagementDomain
        }
    }

    var isDownloadsPopoverShown: Bool {
        downloadsPopover?.isShown ?? false
    }

    var savePopovers: [NSPopover?] {
        [saveIdentityPopover, saveCredentialsPopover, savePaymentMethodPopover]
    }

    var isPasswordManagementDirty: Bool {
        passwordManagementPopover?.viewController.isDirty ?? false
    }

    var isPasswordManagementPopoverShown: Bool {
        passwordManagementPopover?.isShown ?? false
    }

    @MainActor
    var isNetworkProtectionPopoverShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    var bookmarkListPopoverShown: Bool {
        bookmarkListPopover?.isShown ?? false
    }

    func bookmarksButtonPressed(anchorView: NSView, popoverDelegate delegate: NSPopoverDelegate, tab: Tab?) {
        if bookmarkListPopoverShown {
            bookmarkListPopover?.close()
        } else {
            showBookmarkListPopover(usingView: anchorView, withDelegate: delegate, forTab: tab)
        }
    }

    func passwordManagementButtonPressed(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        if passwordManagementPopover?.isShown == true {
            passwordManagementPopover?.close()
        } else {
            showPasswordManagementPopover(selectedCategory: nil, usingView: view, withDelegate: delegate)
        }
    }

    func toggleNetworkProtectionPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        if let networkProtectionPopover = networkProtectionPopover,
           networkProtectionPopover.isShown {
            networkProtectionPopover.close()
        } else {
            showNetworkProtectionPopover(usingView: view, withDelegate: delegate)
        }
    }

    func toggleDownloadsPopover(usingView view: NSView, popoverDelegate: NSPopoverDelegate, downloadsDelegate: DownloadsViewControllerDelegate) {

        if downloadsPopover?.isShown ?? false {
            downloadsPopover?.close()
            return
        }
        guard closeTransientPopovers(),
              view.window != nil
        else { return }

        let popover = DownloadsPopover()
        popover.delegate = popoverDelegate
        popover.viewController.delegate = downloadsDelegate
        downloadsPopover = popover

        show(popover: popover, usingView: view, preferredEdge: .maxY)
    }

    private var downloadsPopoverTimer: Timer?
    func showDownloadsPopoverAndAutoHide(usingView view: NSView, popoverDelegate: NSPopoverDelegate, downloadsDelegate: DownloadsViewControllerDelegate) {
        let timerBlock: (Timer) -> Void = { [weak self] _ in
            self?.downloadsPopoverTimer?.invalidate()
            self?.downloadsPopoverTimer = nil

            if self?.downloadsPopover?.isShown ?? false {
                self?.downloadsPopover?.close()
            }
        }

        if !isDownloadsPopoverShown {
            self.toggleDownloadsPopover(usingView: view, popoverDelegate: popoverDelegate, downloadsDelegate: downloadsDelegate)

            downloadsPopoverTimer = Timer.scheduledTimer(withTimeInterval: Constants.downloadsPopoverAutoHidingInterval,
                                                         repeats: false,
                                                         block: timerBlock)
        }
    }

    func closeTransientPopovers() -> Bool {
        guard savePopovers.allSatisfy({ !($0?.isShown ?? false) }) else {
            return false
        }

        if bookmarkListPopover?.isShown ?? false {
            bookmarkListPopover?.close()
        }

        if passwordManagementPopover?.isShown ?? false {
            passwordManagementPopover?.close()
        }

        if downloadsPopover?.isShown ?? false {
            downloadsPopover?.close()
        }

        return true
    }

    func showBookmarkListPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate, forTab tab: Tab?) {
        guard closeTransientPopovers() else { return }

        let popover = bookmarkListPopover ?? BookmarkListPopover()
        bookmarkListPopover = popover
        popover.delegate = delegate

        if let tab = tab {
            popover.viewController.currentTabWebsite = .init(tab)
        }

        show(popover: popover, usingView: view)
    }

    func showPasswordManagementPopover(selectedCategory: SecureVaultSorting.Category?, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        guard closeTransientPopovers() else { return }

        let popover = passwordManagementPopover ?? PasswordManagementPopover()
        passwordManagementPopover = popover
        popover.viewController.domain = passwordManagementDomain
        popover.delegate = delegate
        show(popover: popover, usingView: view)
        popover.select(category: selectedCategory)
    }

    func hasAnySavePopoversVisible() -> Bool {
        return savePopovers.contains(where: { $0?.isShown ?? false })
    }

    func displaySaveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, automaticallySaved: Bool, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        showSaveCredentialsPopover(usingView: view, withDelegate: delegate)
        saveCredentialsPopover?.viewController.update(credentials: credentials, automaticallySaved: automaticallySaved)
    }

    func displaySavePaymentMethod(_ card: SecureVaultModels.CreditCard, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        showSavePaymentMethodPopover(usingView: view, withDelegate: delegate)
        savePaymentMethodPopover?.viewController.savePaymentMethod(card)
    }

    func displaySaveIdentity(_ identity: SecureVaultModels.Identity, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        showSaveIdentityPopover(usingView: view, withDelegate: delegate)
        saveIdentityPopover?.viewController.saveIdentity(identity)
    }

    func downloadsPopoverClosed() {
        downloadsPopover = nil
        downloadsPopoverTimer?.invalidate()
        downloadsPopoverTimer = nil
    }

    func bookmarkListPopoverClosed() {
        bookmarkListPopover = nil
    }

    func passwordManagementPopoverClosed() {
        passwordManagementPopover = nil
    }

    func saveIdentityPopoverClosed() {
        saveIdentityPopover = nil
    }

    func saveCredentialsPopoverClosed() {
        saveCredentialsPopover = nil
    }

    func savePaymentMethodPopoverClosed() {
        savePaymentMethodPopover = nil
    }

    private func showSaveCredentialsPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = SaveCredentialsPopover()
        popover.delegate = delegate
        saveCredentialsPopover = popover
        show(popover: popover, usingView: view)
    }

    private func showSavePaymentMethodPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = SavePaymentMethodPopover()
        popover.delegate = delegate
        savePaymentMethodPopover = popover
        show(popover: popover, usingView: view)
    }

    private func showSaveIdentityPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = SaveIdentityPopover()
        popover.delegate = delegate
        saveIdentityPopover = popover
        show(popover: popover, usingView: view)
    }

    private func show(popover: NSPopover, usingView view: NSView, preferredEdge edge: NSRectEdge = .minY) {
        view.isHidden = false

        popover.show(relativeTo: view.bounds.insetFromLineOfDeath(), of: view, preferredEdge: edge)
    }

    // MARK: - Network Protection

    func showNetworkProtectionPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let controller = NetworkProtectionTunnelController()
        let statusReporter = DefaultNetworkProtectionStatusReporter(
            statusObserver: ConnectionStatusObserverThroughSession(),
            serverInfoObserver: ConnectionServerInfoObserverThroughSession(),
            connectionErrorObserver: ConnectionErrorObserverThroughSession())

        let menuItems = [
            NetworkProtectionStatusView.Model.MenuItem(
                name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                action: {
                    let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
                    await appLauncher.launchApp(withCommand: .shareFeedback)
            })
        ]

        let popover = NetworkProtectionPopover(controller: controller, statusReporter: statusReporter, menuItems: menuItems)
        popover.delegate = delegate

        networkProtectionPopover = popover
        show(popover: popover, usingView: view, preferredEdge: .maxY)
    }
}
