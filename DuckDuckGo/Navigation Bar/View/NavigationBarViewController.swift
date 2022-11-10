//
//  NavigationBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine
import os.log
import BrowserServicesKit

final class NavigationBarViewController: NSViewController {

    enum Constants {
        static let downloadsButtonAutoHidingInterval: TimeInterval = 5 * 60
    }

    @IBOutlet weak var mouseOverView: MouseOverView!
    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var bookmarkListButton: MouseOverButton!
    @IBOutlet weak var passwordManagementButton: MouseOverButton!
    @IBOutlet weak var downloadsButton: MouseOverButton!
    @IBOutlet weak var navigationButtons: NSView!
    @IBOutlet weak var addressBarContainer: NSView!
    @IBOutlet weak var daxLogo: NSImageView!
    @IBOutlet weak var addressBarStack: NSStackView!

    @IBOutlet var addressBarLeftToNavButtonsConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarProportionalWidthConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarTopConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarBottomConstraint: NSLayoutConstraint!
    @IBOutlet var buttonsTopConstraint: NSLayoutConstraint!
    @IBOutlet var logoWidthConstraint: NSLayoutConstraint!

    lazy var downloadsProgressView: CircularProgressView = {
        let bounds = downloadsButton.bounds
        let width: CGFloat = 27.0
        let frame = NSRect(x: (bounds.width - width) * 0.5, y: (bounds.height - width) * 0.5, width: width, height: width)
        let progressView = CircularProgressView(frame: frame)
        downloadsButton.addSubview(progressView)
        return progressView
    }()
    private static let activeDownloadsImage = NSImage(named: "DownloadsActive")
    private static let inactiveDownloadsImage = NSImage(named: "Downloads")

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private var popovers = NavigationBarPopovers()
    var isDownloadsPopoverShown: Bool {
        popovers.isDownloadsPopoverShown
    }

    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var credentialsToSaveCancellable: AnyCancellable?
    private var passwordManagerNotificationCancellable: AnyCancellable?
    private var pinnedViewsNotificationCancellable: AnyCancellable?
    private var navigationButtonsCancellables = Set<AnyCancellable>()
    private var downloadsCancellables = Set<AnyCancellable>()

    required init?(coder: NSCoder) {
        fatalError("NavigationBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.masksToBounds = false
        addressBarContainer.wantsLayer = true
        addressBarContainer.layer?.masksToBounds = false

        mouseOverView.delegate = self

        setupNavigationButtonMenus()
        subscribeToSelectedTabViewModel()
        listenToPasswordManagerNotifications()
        listenToPinningManagerNotifications()
        listenToMessageNotifications()
        subscribeToDownloads()
        addContextMenu()

        optionsButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.sendAction(on: .leftMouseDown)
        downloadsButton.sendAction(on: .leftMouseDown)
        
        optionsButton.toolTip = UserText.applicationMenuTooltip
        
        #if DEBUG || REVIEW
        addDebugNotificationListeners()
        #endif
    }

    override func viewWillAppear() {
        updateDownloadsButton()
        updatePasswordManagementButton()
        updateBookmarksButton()

        if view.window?.isPopUpWindow == true {
            goBackButton.isHidden = true
            goForwardButton.isHidden = true
            refreshButton.isHidden = true
            optionsButton.isHidden = true
            addressBarTopConstraint.constant = 0
            addressBarBottomConstraint.constant = 0
            addressBarLeftToNavButtonsConstraint.isActive = false
            addressBarProportionalWidthConstraint.isActive = false

            // This pulls the dashboard button to the left for the popup
            NSLayoutConstraint.activate(addressBarStack.addConstraints(to: view, [
                .leading: .leading(multiplier: 1.0, const: 72)
            ]))
        }
    }

    func windowDidBecomeMain() {
        updateNavigationButtons()
    }

    @IBSegueAction func createAddressBarViewController(_ coder: NSCoder) -> AddressBarViewController? {
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("NavigationBarViewController: Failed to init AddressBarViewController")
        }

        self.addressBarViewController = addressBarViewController
        return addressBarViewController
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        if NSApp.isCommandPressed,
           let backItem = selectedTabViewModel.tab.webView.backForwardList.backItem {
            openNewChildTab(with: backItem.url)
        } else {
            selectedTabViewModel.tab.goBack()
        }
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        if NSApp.isCommandPressed,
           let forwardItem = selectedTabViewModel.tab.webView.backForwardList.forwardItem {
            openNewChildTab(with: forwardItem.url)
        } else {
            selectedTabViewModel.tab.goForward()
        }
    }

    private func openNewChildTab(with url: URL) {
        let tab = Tab(content: .url(url), parentTab: tabCollectionViewModel.selectedTabViewModel?.tab, shouldLoadInBackground: true)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)
    }

    @IBAction func refreshAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.reload()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   externalPasswordManagerViewModel: BitwardenSecureVaultViewModel())
        menu.actionDelegate = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @IBAction func bookmarksButtonAction(_ sender: NSButton) {
        popovers.bookmarksButtonPressed(anchorView: bookmarkListButton,
                                        popoverDelegate: self,
                                        tab: tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @IBAction func passwordManagementButtonAction(_ sender: NSButton) {
        popovers.passwordManagementButtonPressed(usingView: passwordManagementButton, withDelegate: self)
    }

    @IBAction func downloadsButtonAction(_ sender: NSButton) {
        toggleDownloadsPopover(keepButtonVisible: false)
    }

    override func mouseDown(with event: NSEvent) {
        if let menu = view.menu, NSEvent.isContextClick(event) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return
        }
        
        super.mouseDown(with: event)
    }
    
    func listenToPasswordManagerNotifications() {
        passwordManagerNotificationCancellable = NotificationCenter.default.publisher(for: .PasswordManagerChanged).sink { [weak self] _ in
            self?.updatePasswordManagementButton()
        }
    }
    
    func listenToPinningManagerNotifications() {
        pinnedViewsNotificationCancellable = NotificationCenter.default.publisher(for: .PinnedViewsChanged).sink { [weak self] notification in
            guard let self = self else {
                return
            }
            
            if let userInfo = notification.userInfo as? [String: Any],
               let viewType = userInfo[LocalPinningManager.pinnedViewChangedNotificationViewTypeKey] as? String,
               let view = PinnableView(rawValue: viewType) {
                switch view {
                case .autofill:
                    self.updatePasswordManagementButton()
                case .bookmarks:
                    self.updateBookmarksButton()
                case .downloads:
                    self.updateDownloadsButton(updatingFromPinnedViewsNotification: true)
                }
            } else {
                assertionFailure("Failed to get changed pinned view type")
                self.updateBookmarksButton()
                self.updatePasswordManagementButton()
            }
        }
    }

    func listenToMessageNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showFireproofingFeedback(_:)),
                                               name: FireproofDomains.Constants.newFireproofDomainNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showPrivateEmailCopiedToClipboard(_:)),
                                               name: Notification.Name.privateEmailCopiedToClipboard,
                                               object: nil)
        if #available(macOS 11, *) {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(showAutoconsentFeedback(_:)),
                                                   name: AutoconsentUserScript.Constants.newSitePopupHidden,
                                                   object: nil)
        }
    }

    @objc private func showPrivateEmailCopiedToClipboard(_ sender: Notification) {
        guard view.window?.isKeyWindow == true else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController.createWithMessage(UserText.privateEmailCopiedToClipboard)
            viewController.show(onParent: self, relativeTo: self.optionsButton)
        }

    }

    @objc private func showFireproofingFeedback(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
              let domain = sender.userInfo?[FireproofDomains.Constants.newFireproofDomainKey] as? String else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController.createWithMessage(UserText.domainIsFireproof(domain: domain))
            viewController.show(onParent: self, relativeTo: self.optionsButton)
        }
    }

    @objc private func showAutoconsentFeedback(_ sender: Notification) {
        if #available(macOS 11, *) {
            guard view.window?.isKeyWindow == true,
                  let topUrl = sender.userInfo?["topUrl"] as? URL
            else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.tabCollectionViewModel.selectedTabViewModel?.tab.url == topUrl else {
                          // if the tab is not active, don't show the popup
                          return
                      }
                self.addressBarViewController?.addressBarButtonsViewController?.showBadgeNotification(.cookieManaged)                
            }
        }
    }

    func toggleDownloadsPopover(keepButtonVisible: Bool) {

        downloadsButton.isHidden = false
        if keepButtonVisible {
            setDownloadButtonHidingTimer()
        }

        popovers.toggleDownloadsPopover(usingView: downloadsButton, popoverDelegate: self, downloadsDelegate: self)
    }

    private func setupNavigationButtonMenus() {
        let backButtonMenu = NSMenu()
        backButtonMenu.delegate = goBackButtonMenuDelegate
        goBackButton.menu = backButtonMenu
        let forwardButtonMenu = NSMenu()
        forwardButtonMenu.delegate = goForwardButtonMenuDelegate
        goForwardButton.menu = forwardButtonMenu
        
        goBackButton.toolTip = UserText.navigateBackTooltip
        goForwardButton.toolTip = UserText.navigateForwardTooltip
        refreshButton.toolTip = UserText.refreshPageTooltip
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToNavigationActionFlags()
            self?.subscribeToCredentialsToSave()
            self?.subscribeToTabContent()
        }
    }

    private func subscribeToTabContent() {
        urlCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.$content
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.updatePasswordManagementButton()
            })
    }

    var daxFadeInAnimation: DispatchWorkItem?
    func resizeAddressBarForHomePage(_ homePage: Bool, animated: Bool) {
        daxFadeInAnimation?.cancel()

        let verticalPadding: CGFloat = view.window?.isPopUpWindow == true ? 0 : 6

        let barTop = animated ? addressBarTopConstraint.animator() : addressBarTopConstraint
        barTop?.constant = homePage ? 16 : verticalPadding

        let bottom = animated ? addressBarBottomConstraint.animator() : addressBarBottomConstraint
        bottom?.constant = homePage ? 2 : verticalPadding

        let logoWidth = animated ? logoWidthConstraint.animator() : logoWidthConstraint
        logoWidth?.constant = homePage ? 44 : 0

        daxLogo.alphaValue = homePage ? 0 : 1 // initial value to animate from

        if animated {
            let fadeIn = DispatchWorkItem { [weak self] in
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    self?.daxLogo.animator().alphaValue = homePage ? 1 : 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: fadeIn)
            self.daxFadeInAnimation = fadeIn
        } else {
            daxLogo.alphaValue = homePage ? 1 : 0
        }

    }

    private func subscribeToDownloads() {
        DownloadListCoordinator.shared.updates
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] update in
                guard let self = self else { return }

                let shouldShowPopover = update.kind == .updated
                    && update.item.destinationURL != nil
                    && update.item.tempURL == nil
                    && WindowControllersManager.shared.lastKeyMainWindowController?.window === self.downloadsButton.window

                if shouldShowPopover {
                    self.popovers.showDownloadsPopoverAndAutoHide(usingView: self.passwordManagementButton,
                                                                  popoverDelegate: self,
                                                                  downloadsDelegate: self)
                }
                self.updateDownloadsButton()
            }
            .store(in: &downloadsCancellables)
        DownloadListCoordinator.shared.progress
            .publisher(for: \.fractionCompleted)
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .map { _ in
                let progress = DownloadListCoordinator.shared.progress
                return progress.fractionCompleted == 1.0 || progress.totalUnitCount == 0 ? nil : progress.fractionCompleted
            }
            .assign(to: \.progress, onWeaklyHeld: downloadsProgressView)
            .store(in: &downloadsCancellables)
    }
    
    private func addContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        self.view.menu = menu
    }

    private func updatePasswordManagementButton() {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .autofill)
        menu.addItem(withTitle: title, action: #selector(toggleAutofillPanelPinning), keyEquivalent: "")
        
        passwordManagementButton.menu = menu
        passwordManagementButton.toolTip = UserText.autofillShortcutTooltip
        
        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url

        passwordManagementButton.image = NSImage(named: "PasswordManagement")

        if popovers.hasAnySavePopoversVisible() {
            return
        }

        if popovers.isPasswordManagementDirty {
            passwordManagementButton.image = NSImage(named: "PasswordManagementDirty")
            return
        }

        if LocalPinningManager.shared.isPinned(.autofill) {
            passwordManagementButton.isHidden = false
        } else {
            passwordManagementButton.isHidden = !popovers.isPasswordManagementPopoverShown
        }

        popovers.passwordManagementDomain = nil
        guard let url = url, let domain = url.host else {
            return
        }
        popovers.passwordManagementDomain = domain
    }

    private func updateDownloadsButton(updatingFromPinnedViewsNotification: Bool = false) {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .downloads)
        menu.addItem(withTitle: title, action: #selector(toggleDownloadsPanelPinning(_:)), keyEquivalent: "")
        
        downloadsButton.menu = menu
        downloadsButton.toolTip = UserText.downloadsShortcutTooltip
        
        if LocalPinningManager.shared.isPinned(.downloads) {
            downloadsButton.isHidden = false
            return
        }

        let hasActiveDownloads = DownloadListCoordinator.shared.hasActiveDownloads
        downloadsButton.image = hasActiveDownloads ? Self.activeDownloadsImage : Self.inactiveDownloadsImage
        let isTimerActive = downloadsButtonHidingTimer != nil

        downloadsButton.isHidden = !(hasActiveDownloads || isTimerActive)

        if !downloadsButton.isHidden { setDownloadButtonHidingTimer() }
        downloadsButton.isMouseDown = popovers.isDownloadsPopoverShown
        
        // If the user has selected Hide Downloads from the navigation bar context menu, and no downloads are active, then force it to be hidden
        // even if the timer is active.
        if updatingFromPinnedViewsNotification {
            if !LocalPinningManager.shared.isPinned(.downloads) {
                invalidateDownloadButtonHidingTimer()
                downloadsButton.isHidden = !hasActiveDownloads
            }
        }
    }

    private var downloadsButtonHidingTimer: Timer?
    private func setDownloadButtonHidingTimer() {
        guard downloadsButtonHidingTimer == nil else { return }

        let timerBlock: (Timer) -> Void = { [weak self] _ in
            guard let self = self else { return }

            self.invalidateDownloadButtonHidingTimer()
            self.hideDownloadButtonIfPossible()
        }

        downloadsButtonHidingTimer = Timer.scheduledTimer(withTimeInterval: Constants.downloadsButtonAutoHidingInterval,
                                                          repeats: false,
                                                          block: timerBlock)
    }

    private func invalidateDownloadButtonHidingTimer() {
        self.downloadsButtonHidingTimer?.invalidate()
        self.downloadsButtonHidingTimer = nil
    }

    private func hideDownloadButtonIfPossible() {
        if LocalPinningManager.shared.isPinned(.downloads) ||
            DownloadListCoordinator.shared.hasActiveDownloads ||
            popovers.isDownloadsPopoverShown { return }
        
        downloadsButton.isHidden = true
    }

    private func updateBookmarksButton() {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .bookmarks)
        menu.addItem(withTitle: title, action: #selector(toggleBookmarksPanelPinning(_:)), keyEquivalent: "")
        
        bookmarkListButton.menu = menu
        bookmarkListButton.toolTip = UserText.bookmarksShortcutTooltip
        
        if LocalPinningManager.shared.isPinned(.bookmarks) {
            bookmarkListButton.isHidden = false
        } else {
            bookmarkListButton.isHidden = !popovers.bookmarkListPopoverShown
        }
    }

    private func subscribeToCredentialsToSave() {
        credentialsToSaveCancellable = tabCollectionViewModel.selectedTabViewModel?.$autofillDataToSave
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in
                if let data = $0 {
                    self?.promptToSaveAutofillData(data)
                    self?.tabCollectionViewModel.selectedTabViewModel?.autofillDataToSave = nil
                }
            })
    }

    private func promptToSaveAutofillData(_ data: AutofillData) {
        let autofillPreferences = AutofillPreferences()

        if autofillPreferences.askToSaveUsernamesAndPasswords, let credentials = data.credentials {
            os_log("Presenting Save Credentials popover", log: .passwordManager)
            popovers.displaySaveCredentials(credentials,
                                            automaticallySaved: data.automaticallySavedCredentials,
                                            usingView: passwordManagementButton,
                                            withDelegate: self)
        } else if autofillPreferences.askToSavePaymentMethods, let card = data.creditCard {
            os_log("Presenting Save Payment Method popover", log: .passwordManager)
            popovers.displaySavePaymentMethod(card,
                                              usingView: passwordManagementButton,
                                              withDelegate: self)
        } else if autofillPreferences.askToSaveAddresses, let identity = data.identity {
            os_log("Presenting Save Identity popover", log: .passwordManager)
            popovers.displaySaveIdentity(identity,
                                         usingView: passwordManagementButton,
                                         withDelegate: self)
        } else {
            os_log("Received save autofill data call, but there was no data to present", log: .passwordManager)
        }
    }

    private func subscribeToNavigationActionFlags() {
        navigationButtonsCancellables.forEach { $0.cancel() }
        navigationButtonsCancellables.removeAll()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            goBackButton.isEnabled = false
            goForwardButton.isEnabled = false
            return
        }
        selectedTabViewModel.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)
    }

    private func updateNavigationButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        goBackButton.isEnabled = selectedTabViewModel.canGoBack
        goForwardButton.isEnabled = selectedTabViewModel.canGoForward
        refreshButton.isEnabled = selectedTabViewModel.canReload
    }

}

extension NavigationBarViewController: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        addressBarViewController?.addressBarButtonsViewController?.isMouseOverNavigationBar = isMouseOver
    }

}

extension NavigationBarViewController: NSMenuDelegate {
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let bookmarksBarTitle = PersistentAppInterfaceSettings.shared.showBookmarksBar ? UserText.hideBookmarksBar : UserText.showBookmarksBar
        menu.addItem(withTitle: bookmarksBarTitle, action: #selector(toggleBookmarksBar), keyEquivalent: "B")
        
        menu.addItem(NSMenuItem.separator())
        
        let autofillTitle = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .autofill)
        menu.addItem(withTitle: autofillTitle, action: #selector(toggleAutofillPanelPinning), keyEquivalent: "A")

        let bookmarksTitle = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .bookmarks)
        menu.addItem(withTitle: bookmarksTitle, action: #selector(toggleBookmarksPanelPinning), keyEquivalent: "K")

        let downloadsTitle = LocalPinningManager.shared.toggleShortcutInterfaceTitle(for: .downloads)
        menu.addItem(withTitle: downloadsTitle, action: #selector(toggleDownloadsPanelPinning), keyEquivalent: "J")
    }
    
    @objc
    private func toggleBookmarksBar(_ sender: NSMenuItem) {
        PersistentAppInterfaceSettings.shared.showBookmarksBar.toggle()
    }
    
    @objc
    private func toggleAutofillPanelPinning(_ sender: NSMenuItem) {
        LocalPinningManager.shared.togglePinning(for: .autofill)
    }
    
    @objc
    private func toggleBookmarksPanelPinning(_ sender: NSMenuItem) {
        LocalPinningManager.shared.togglePinning(for: .bookmarks)
    }
    
    @objc
    private func toggleDownloadsPanelPinning(_ sender: NSMenuItem) {
        LocalPinningManager.shared.togglePinning(for: .downloads)
    }

}

extension NavigationBarViewController: OptionsButtonMenuDelegate {
    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu) {
        BitwardenManager.shared.openBitwarden()
    }

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem) {
        addressBarViewController?
            .addressBarButtonsViewController?
            .openBookmarkPopover(setFavorite: false, accessPoint: .init(sender: sender, default: .moreMenu))
    }

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu) {
        popovers.showBookmarkListPopover(usingView: bookmarkListButton,
                                         withDelegate: self,
                                         forTab: tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func optionsButtonMenuRequestedToggleBookmarksBar(_ menu: NSMenu) {
        PersistentAppInterfaceSettings.shared.showBookmarksBar.toggle()
    }
    
    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu) {
        WindowControllersManager.shared.showBookmarksTab()
    }
    
    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu) {
        DataImportViewController.show()
    }

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category) {
        popovers.showPasswordManagementPopover(selectedCategory: selectedCategory,
                                               usingView: passwordManagementButton,
                                               withDelegate: self)
    }

    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu) {
        toggleDownloadsPopover(keepButtonVisible: false)
    }

    func optionsButtonMenuRequestedPrint(_ menu: NSMenu) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.printWebView(self)
    }

}

extension NavigationBarViewController: NSPopoverDelegate {

    /// We check references here because these popovers might be on other windows.
    func popoverDidClose(_ notification: Notification) {
        if let popover = popovers.downloadsPopover, notification.object as AnyObject? === popover {
            popovers.downloadsPopoverClosed()
            updateDownloadsButton()
        } else if let popover = popovers.bookmarkListPopover, notification.object as AnyObject? === popover {
            popovers.bookmarkListPopoverClosed()
            updateBookmarksButton()
        } else if let popover = popovers.passwordManagementPopover, notification.object as AnyObject? === popover {
            popovers.passwordManagementPopoverClosed()
        } else if let popover = popovers.saveIdentityPopover, notification.object as AnyObject? === popover {
            popovers.saveIdentityPopoverClosed()
            updatePasswordManagementButton()
        } else if let popover = popovers.saveCredentialsPopover, notification.object as AnyObject? === popover {
            popovers.saveCredentialsPopoverClosed()
            updatePasswordManagementButton()
        } else if let popover = popovers.savePaymentMethodPopover, notification.object as AnyObject? === popover {
            popovers.savePaymentMethodPopoverClosed()
            updatePasswordManagementButton()
        }
    }

}

extension NavigationBarViewController: DownloadsViewControllerDelegate {

    func clearDownloadsActionTriggered() {
        invalidateDownloadButtonHidingTimer()
        hideDownloadButtonIfPossible()
    }

}

#if DEBUG || REVIEW
extension NavigationBarViewController {
    
    fileprivate func addDebugNotificationListeners() {
        NotificationCenter.default.addObserver(forName: .ShowSaveCredentialsPopover, object: nil, queue: .main) { [weak self] _ in
            self?.showMockSaveCredentialsPopover()
        }
        
        NotificationCenter.default.addObserver(forName: .ShowCredentialsSavedPopover, object: nil, queue: .main) { [weak self] _ in
            self?.showMockCredentialsSavedPopover()
        }
    }

    fileprivate func showMockSaveCredentialsPopover() {
        let account = SecureVaultModels.WebsiteAccount(title: nil, username: "example-username", domain: "example.com")
        let mockCredentials = SecureVaultModels.WebsiteCredentials(account: account, password: "password".data(using: .utf8)!)

        popovers.displaySaveCredentials(mockCredentials, automaticallySaved: false,
                                        usingView: passwordManagementButton,
                                        withDelegate: self)
    }
    
    fileprivate func showMockCredentialsSavedPopover() {
        let account = SecureVaultModels.WebsiteAccount(title: nil, username: "example-username", domain: "example.com")
        let mockCredentials = SecureVaultModels.WebsiteCredentials(account: account, password: "password".data(using: .utf8)!)

        popovers.displaySaveCredentials(mockCredentials,
                                        automaticallySaved: true,
                                        usingView: passwordManagementButton,
                                        withDelegate: self)
    }
    
}
#endif
