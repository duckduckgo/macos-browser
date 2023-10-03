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
import AppKit

#if NETWORK_PROTECTION
import Combine
import NetworkProtection
import NetworkProtectionUI
#endif

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

#if NETWORK_PROTECTION
    private(set) var networkProtectionPopover: NetworkProtectionPopover?
#endif

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
#if NETWORK_PROTECTION
        networkProtectionPopover?.isShown ?? false
#else
        return false
#endif
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
#if NETWORK_PROTECTION
        if let networkProtectionPopover, networkProtectionPopover.isShown {
            networkProtectionPopover.close()
        } else {
            let featureVisibility = DefaultNetworkProtectionVisibility()

            if featureVisibility.isNetworkProtectionVisible() {
                showNetworkProtectionPopover(usingView: view, withDelegate: delegate)
            } else {
                featureVisibility.disableForWaitlistUsers()
            }
        }
#endif
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

        show(popover, positionedBelow: view)
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

#if NETWORK_PROTECTION
        if networkProtectionPopover?.isShown ?? false {
            networkProtectionPopover?.close()
        }
#endif

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

        LocalBookmarkManager.shared.requestSync()
        show(popover, positionedBelow: view)
    }

    func showPasswordManagementPopover(selectedCategory: SecureVaultSorting.Category?, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        guard closeTransientPopovers() else { return }

        let popover = passwordManagementPopover ?? PasswordManagementPopover()
        passwordManagementPopover = popover
        popover.viewController.domain = passwordManagementDomain
        popover.delegate = delegate
        show(popover, positionedBelow: view)
        popover.select(category: selectedCategory)
    }

    func showPasswordManagerPopover(selectedWebsiteAccount: SecureVaultModels.WebsiteAccount, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = passwordManagementPopover ?? PasswordManagementPopover()
        passwordManagementPopover = popover
        popover.delegate = delegate
        show(popover, positionedBelow: view)
        popover.select(websiteAccount: selectedWebsiteAccount)
    }

    func hasAnySavePopoversVisible() -> Bool {
        return savePopovers.contains(where: { $0?.isShown ?? false })
    }

    func displaySaveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, automaticallySaved: Bool, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        if !automaticallySaved {
            showSaveCredentialsPopover(usingView: view, withDelegate: delegate)
            saveCredentialsPopover?.viewController.update(credentials: credentials, automaticallySaved: automaticallySaved)
        } else {
            NotificationCenter.default.post(name: .loginAutoSaved, object: credentials.account)
        }
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
        show(popover, positionedBelow: view)
    }

    private func showSavePaymentMethodPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = SavePaymentMethodPopover()
        popover.delegate = delegate
        savePaymentMethodPopover = popover
        show(popover, positionedBelow: view)
    }

    private func showSaveIdentityPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = SaveIdentityPopover()
        popover.delegate = delegate
        saveIdentityPopover = popover
        show(popover, positionedBelow: view)
    }

    private func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    // MARK: - Network Protection

#if NETWORK_PROTECTION
    func showNetworkProtectionPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = networkProtectionPopover ?? {
            let controller = NetworkProtectionIPCTunnelController()

            let statusObserver = ConnectionStatusObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                        platformDidWakeNotification: NSWorkspace.didWakeNotification)
            let statusInfoObserver = ConnectionServerInfoObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                                platformDidWakeNotification: NSWorkspace.didWakeNotification)
            let connectionErrorObserver = ConnectionErrorObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                                platformDidWakeNotification: NSWorkspace.didWakeNotification)
            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: statusObserver,
                serverInfoObserver: statusInfoObserver,
                connectionErrorObserver: connectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
            )

            let menuItems = [
                NetworkProtectionStatusView.Model.MenuItem(
                    name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                    action: {
                        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
                        await appLauncher.launchApp(withCommand: .shareFeedback)
                })
            ]

            let onboardingStatusPublisher = UserDefaults.shared.networkProtectionOnboardingStatusPublisher

            let popover = NetworkProtectionPopover(controller: controller, onboardingStatusPublisher: onboardingStatusPublisher, statusReporter: statusReporter, menuItems: menuItems)
            popover.delegate = delegate

            networkProtectionPopover = popover
            return popover
        }()
        show(popover, positionedBelow: view)
    }
#endif
}

extension Notification.Name {
    static let loginAutoSaved = Notification.Name(rawValue: "loginAutoSaved")
}
