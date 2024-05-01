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
import Combine
import NetworkProtection
import NetworkProtectionUI
import NetworkProtectionIPC

protocol PopoverPresenter {
    func show(_ popover: NSPopover, positionedBelow view: NSView)
}

protocol NetPPopoverManager: AnyObject {
    var ipcClient: NetworkProtectionIPCClient { get }
    var isShown: Bool { get }

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate)
    func close()

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate)
}

extension PopoverPresenter {
    func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false
        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }
}

final class NavigationBarPopovers: PopoverPresenter {

    enum Constants {
        static let downloadsPopoverAutoHidingInterval: TimeInterval = 10
    }

    private(set) var bookmarkListPopover: BookmarkListPopover?
    private(set) var saveCredentialsPopover: SaveCredentialsPopover?
    private(set) var saveIdentityPopover: SaveIdentityPopover?
    private(set) var savePaymentMethodPopover: SavePaymentMethodPopover?
    private(set) var autofillPopoverPresenter: AutofillPopoverPresenter
    private(set) var downloadsPopover: DownloadsPopover?

    private let networkProtectionPopoverManager: NetPPopoverManager

    init(networkProtectionPopoverManager: NetPPopoverManager, autofillPopoverPresenter: AutofillPopoverPresenter) {
        self.networkProtectionPopoverManager = networkProtectionPopoverManager
        self.autofillPopoverPresenter = autofillPopoverPresenter
    }

    var passwordManagementDomain: String? {
        didSet {
            autofillPopoverPresenter.passwordDomain = passwordManagementDomain
        }
    }

    var isDownloadsPopoverShown: Bool {
        downloadsPopover?.isShown ?? false
    }

    var savePopovers: [NSPopover?] {
        [saveIdentityPopover, saveCredentialsPopover, savePaymentMethodPopover]
    }

    var isPasswordManagementDirty: Bool {
        autofillPopoverPresenter.popoverIsDirty
    }

    var isPasswordManagementPopoverShown: Bool {
        autofillPopoverPresenter.popoverIsShown
    }

    @MainActor
    var isNetworkProtectionPopoverShown: Bool {
        networkProtectionPopoverManager.isShown
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
        if autofillPopoverPresenter.popoverIsShown == true && view.window == autofillPopoverPresenter.popoverPresentingWindow {
            autofillPopoverPresenter.dismiss()
        } else {
            showPasswordManagementPopover(selectedCategory: nil, usingView: view, withDelegate: delegate)
        }
    }

    func toggleNetworkProtectionPopover(usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        networkProtectionPopoverManager.toggle(positionedBelow: view, withDelegate: delegate)
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

        if autofillPopoverPresenter.popoverIsShown {
            autofillPopoverPresenter.dismiss()
        }

        if downloadsPopover?.isShown ?? false {
            downloadsPopover?.close()
        }

        if networkProtectionPopoverManager.isShown {
            networkProtectionPopoverManager.close()
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

        LocalBookmarkManager.shared.requestSync()
        show(popover, positionedBelow: view)
    }

    func showPasswordManagementPopover(selectedCategory: SecureVaultSorting.Category?, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        guard closeTransientPopovers() else { return }

        autofillPopoverPresenter.show(positionedBelow: view, withDomain: passwordManagementDomain, selectedCategory: selectedCategory)
    }

    func showPasswordManagerPopover(selectedWebsiteAccount: SecureVaultModels.WebsiteAccount, usingView view: NSView, withDelegate delegate: NSPopoverDelegate) {
        autofillPopoverPresenter.show(positionedBelow: view, withSelectedAccount: selectedWebsiteAccount)
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

    func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    // MARK: - VPN

    func showNetworkProtectionPopover(
        positionedBelow view: NSView,
        withDelegate delegate: NSPopoverDelegate) {
            networkProtectionPopoverManager.show(positionedBelow: view, withDelegate: delegate)
    }
}

extension Notification.Name {
    static let loginAutoSaved = Notification.Name(rawValue: "loginAutoSaved")
    static let passwordsAutoPinned = Notification.Name(rawValue: "passwordsAutoPinned")
}
