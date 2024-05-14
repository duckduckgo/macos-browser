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

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover
    func close()

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover?
}

extension PopoverPresenter {
    func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false
        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }
}

final class NavigationBarPopovers: NSObject, PopoverPresenter {

    enum Constants {
        static let downloadsPopoverAutoHidingInterval: TimeInterval = 10
    }

    private(set) var bookmarkListPopover: BookmarkListPopover?
    private(set) var saveCredentialsPopover: SaveCredentialsPopover?
    private(set) var saveIdentityPopover: SaveIdentityPopover?
    private(set) var savePaymentMethodPopover: SavePaymentMethodPopover?
    private(set) var autofillPopoverPresenter: AutofillPopoverPresenter
    private(set) var downloadsPopover: DownloadsPopover?

    private var privacyDashboardPopover: PrivacyDashboardPopover?
    private var privacyInfoCancellable: AnyCancellable?
    private var privacyDashboadPendingUpdatesCancellable: AnyCancellable?

    private(set) var bookmarkPopover: AddBookmarkPopover?
    private weak var bookmarkPopoverDelegate: NSPopoverDelegate?

    private func bookmarkPopoverCreatingIfNeeded() -> AddBookmarkPopover {
        return bookmarkPopover ?? {
            let popover = AddBookmarkPopover()
            popover.delegate = self
            self.bookmarkPopover = popover
            return popover
        }()
    }

    private let networkProtectionPopoverManager: NetPPopoverManager

    private var popoverIsShownCancellables = Set<AnyCancellable>()

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

    var isEditBookmarkPopoverShown: Bool {
        bookmarkPopover?.isShown ?? false
    }

    func bookmarksButtonPressed(_ button: MouseOverButton, popoverDelegate delegate: NSPopoverDelegate, tab: Tab?) {
        if bookmarkListPopoverShown {
            bookmarkListPopover?.close()
        } else {
            showBookmarkListPopover(from: button, withDelegate: delegate, forTab: tab)
        }
    }

    func passwordManagementButtonPressed(_ button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        if autofillPopoverPresenter.popoverIsShown == true && button.window == autofillPopoverPresenter.popoverPresentingWindow {
            autofillPopoverPresenter.dismiss()
        } else {
            showPasswordManagementPopover(selectedCategory: nil, from: button, withDelegate: delegate)
        }
    }

    func toggleNetworkProtectionPopover(from button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        if let popover = networkProtectionPopoverManager.toggle(positionedBelow: button, withDelegate: delegate) {
            bindIsMouseDownState(of: button, to: popover)
        }
    }

    func toggleDownloadsPopover(from button: MouseOverButton, popoverDelegate: NSPopoverDelegate, downloadsDelegate: DownloadsViewControllerDelegate) {
        if downloadsPopover?.isShown ?? false {
            downloadsPopover?.close()
            return
        }
        guard closeTransientPopovers(),
              button.window != nil else { return }

        let popover = DownloadsPopover()
        popover.delegate = popoverDelegate
        popover.viewController.delegate = downloadsDelegate
        downloadsPopover = popover

        show(popover, positionedBelow: button)
    }

    func togglePrivacyDashboardPopover(for tabViewModel: TabViewModel?, from button: MouseOverButton) {
        if privacyDashboardPopover?.isShown == true {
            closePrivacyDashboard()
        } else if let tabViewModel {
            openPrivacyDashboard(for: tabViewModel, from: button)
        }
    }

    private var downloadsPopoverTimer: Timer?
    func showDownloadsPopoverAndAutoHide(usingView button: MouseOverButton, popoverDelegate: NSPopoverDelegate, downloadsDelegate: DownloadsViewControllerDelegate) {
        let timerBlock: (Timer) -> Void = { [weak self] _ in
            self?.downloadsPopoverTimer?.invalidate()
            self?.downloadsPopoverTimer = nil

            if self?.downloadsPopover?.isShown ?? false {
                self?.downloadsPopover?.close()
            }
        }

        if !isDownloadsPopoverShown {
            self.toggleDownloadsPopover(from: button, popoverDelegate: popoverDelegate, downloadsDelegate: downloadsDelegate)

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

        if bookmarkPopover?.isShown ?? false {
            bookmarkPopover?.close()
        }

        if privacyDashboardPopover?.isShown ?? false {
            privacyDashboardPopover?.close()
        }

        return true
    }

    func showBookmarkListPopover(from button: MouseOverButton, withDelegate delegate: NSPopoverDelegate, forTab tab: Tab?) {
        guard closeTransientPopovers() else { return }

        let popover = bookmarkListPopover ?? BookmarkListPopover()
        bookmarkListPopover = popover
        popover.delegate = delegate

        if let tab = tab {
            popover.viewController.currentTabWebsite = .init(tab)
        }

        LocalBookmarkManager.shared.requestSync()
        show(popover, positionedBelow: button)
    }

    func showEditBookmarkPopover(with bookmark: Bookmark, isNew: Bool, from button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        guard closeTransientPopovers() else { return }

        let bookmarkPopover = bookmarkPopoverCreatingIfNeeded()
        bookmarkPopover.isNew = isNew
        bookmarkPopover.bookmark = bookmark
        self.bookmarkPopoverDelegate = delegate
        show(bookmarkPopover, positionedBelow: button)
    }

    func closeEditBookmarkPopover() {
        bookmarkPopover?.close()
    }

    func openPrivacyDashboard(for tabViewModel: TabViewModel, from button: MouseOverButton) {
        guard closeTransientPopovers() else { return }

        let popover = PrivacyDashboardPopover()
        popover.delegate = self
        self.privacyDashboardPopover = popover
        self.subscribePrivacyDashboardPendingUpdates(for: popover)

        popover.viewController.updateTabViewModel(tabViewModel)

        let positioningRectInWindow = button.convert(button.bounds, to: button.window?.contentView)
        popover.setPreferredMaxHeight(positioningRectInWindow.origin.y)

        show(popover, positionedBelow: button)
        bindIsMouseDownState(of: button, to: popover)

        privacyInfoCancellable = tabViewModel.tab.privacyInfoPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak popover, weak tabViewModel] _ in
                guard let popover, popover.isShown, let tabViewModel else { return }
                popover.viewController.updateTabViewModel(tabViewModel)
            }
    }

    private func subscribePrivacyDashboardPendingUpdates(for privacyDashboardPopover: PrivacyDashboardPopover) {
        privacyDashboadPendingUpdatesCancellable?.cancel()
        guard NSApp.runType.requiresEnvironment else { return }
        let privacyDashboardViewController = privacyDashboardPopover.viewController

        privacyDashboadPendingUpdatesCancellable = privacyDashboardViewController.rulesUpdateObserver
            .$pendingUpdates.dropFirst().receive(on: DispatchQueue.main).sink { [weak privacyDashboardPopover] _ in
                let isPendingUpdate = privacyDashboardViewController.isPendingUpdates()

            // Prevent popover from being closed when clicking away, while pending updates
            if isPendingUpdate {
                privacyDashboardPopover?.behavior = .applicationDefined
            } else {
                privacyDashboardPopover?.close()
#if DEBUG
                privacyDashboardPopover?.behavior = .semitransient
#else
                privacyDashboardPopover?.behavior = .transient
#endif
            }
        }
    }

    func closePrivacyDashboard() {
        // Prevent popover from being closed with Privacy Entry Point Button, while pending updates
        guard let popover = privacyDashboardPopover,
              !popover.viewController.isPendingUpdates() else { return }

        popover.close()
    }

    func showPasswordManagementPopover(selectedCategory: SecureVaultSorting.Category?, from button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        guard closeTransientPopovers() else { return }

        let popover = autofillPopoverPresenter.show(positionedBelow: button, withDomain: passwordManagementDomain, selectedCategory: selectedCategory)
        bindIsMouseDownState(of: button, to: popover)
    }

    func showPasswordManagerPopover(selectedWebsiteAccount: SecureVaultModels.WebsiteAccount, from button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        let popover = autofillPopoverPresenter.show(positionedBelow: button, withSelectedAccount: selectedWebsiteAccount)
        bindIsMouseDownState(of: button, to: popover)
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

    func show(_ popover: NSPopover, positionedBelow button: MouseOverButton) {
        button.isHidden = false

        popover.show(positionedBelow: button.bounds.insetFromLineOfDeath(flipped: button.isFlipped), in: button)
        bindIsMouseDownState(of: button, to: popover)
    }

    // keep button.isMouseDown ON while the popover is shown
    func bindIsMouseDownState(of button: MouseOverButton, to popover: NSPopover) {
        popoverIsShownCancellables.removeAll()

        button.publisher(for: \.isMouseDown).sink { [weak button, weak popover] isMouseDown in
            guard let button, let popover else { return }
            if !isMouseDown && popover.isShown {
                button.isMouseDown = true
            }
        }.store(in: &popoverIsShownCancellables)

        popover.publisher(for: \.isShown).sink { [weak button] isShown in
            guard let button else { return }
            if isShown {
                button.isMouseDown = true
            } else {
                button.isMouseDown = false
            }
        }.store(in: &popoverIsShownCancellables)
    }

    // MARK: - VPN

    func showNetworkProtectionPopover(positionedBelow button: MouseOverButton, withDelegate delegate: NSPopoverDelegate) {
        let popover = networkProtectionPopoverManager.show(positionedBelow: button, withDelegate: delegate)
        bindIsMouseDownState(of: button, to: popover)
    }
}

extension NavigationBarPopovers: NSPopoverDelegate {

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        switch popover {
        case bookmarkPopover:
            // fix popover reopening on next bookmarkButtonAction (on macOS 11)
            DispatchQueue.main.async { [weak self] in
                if let bookmarkPopover = self?.bookmarkPopover, bookmarkPopover.isShown {
                    bookmarkPopover.close()
                }
            }
            return false

        default:
            return true
        }
    }

    func popoverWillClose(_ notification: Notification) {
        switch notification.object as? NSPopover {
        case bookmarkPopover:
            bookmarkPopoverDelegate?.popoverWillClose?(notification)
            bookmarkPopover?.popoverWillClose()

        default:
            break
        }
    }

    func popoverDidClose(_ notification: Notification) {
        switch notification.object as? NSPopover {
        case bookmarkPopover:
            bookmarkPopoverDelegate?.popoverDidClose?(notification)
            bookmarkPopover = nil

        case privacyDashboardPopover:
            privacyDashboardPopover = nil
            privacyInfoCancellable = nil
            privacyDashboadPendingUpdatesCancellable = nil

        default: break
        }
    }

}

extension Notification.Name {
    static let loginAutoSaved = Notification.Name(rawValue: "loginAutoSaved")
}
