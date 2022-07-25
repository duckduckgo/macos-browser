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

// swiftlint:disable type_body_length file_length
final class NavigationBarViewController: NSViewController {

    enum Constants {
        static let downloadsButtonAutoHidingInterval: TimeInterval = 5 * 60
        static let downloadsPopoverAutoHidingInterval: TimeInterval = 10
    }

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var bookmarkListButton: NSButton!
    @IBOutlet weak var passwordManagementButton: NSButton!
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

    private lazy var bookmarkListPopover: BookmarkListPopover = {
        let popover = BookmarkListPopover()
        popover.delegate = self
        return popover
    }()

    private lazy var saveCredentialsPopover: SaveCredentialsPopover = {
        let popover = SaveCredentialsPopover()
        popover.delegate = self
        return popover
    }()

    private lazy var saveIdentityPopover: SaveIdentityPopover = {
        let popover = SaveIdentityPopover()
        popover.delegate = self
        return popover
    }()

    private lazy var savePaymentMethodPopover: SavePaymentMethodPopover = {
        let popover = SavePaymentMethodPopover()
        popover.delegate = self
        return popover
    }()

    private var popovers: [NSPopover] {
        return [saveCredentialsPopover, saveIdentityPopover, savePaymentMethodPopover]
    }

    private lazy var passwordManagementPopover: PasswordManagementPopover = PasswordManagementPopover()
    private lazy var downloadsPopover: DownloadsPopover = {
        let downloadsPopover = DownloadsPopover()
        downloadsPopover.delegate = self
        (downloadsPopover.contentViewController as? DownloadsViewController)?.delegate = self
        return downloadsPopover
    }()
    var isDownloadsPopoverShown: Bool {
        downloadsPopover.isShown
    }

    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var credentialsToSaveCancellable: AnyCancellable?
    private var passwordManagerNotificationCancellable: AnyCancellable?
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

        setupNavigationButtonMenus()
        subscribeToSelectedTabViewModel()
        listenToPasswordManagerNotifications()
        listenToMessageNotifications()
        subscribeToDownloads()

        optionsButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.sendAction(on: .leftMouseDown)
        downloadsButton.sendAction(on: .leftMouseDown)
        
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

        Pixel.fire(.refresh(source: .init(sender: sender, default: .button)))
        selectedTabViewModel.reload()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel)
        menu.actionDelegate = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @IBAction func bookmarksButtonAction(_ sender: NSButton) {
        showBookmarkListPopover()
    }

    @IBAction func passwordManagementButtonAction(_ sender: NSButton) {
        // Use the category that is already selected

        if passwordManagementPopover.isShown {
            passwordManagementPopover.close()
        } else {
            showPasswordManagementPopover(sender: sender, selectedCategory: nil)
        }
    }

    @IBAction func downloadsButtonAction(_ sender: NSButton) {
        toggleDownloadsPopover(keepButtonVisible: false)
    }

    func listenToPasswordManagerNotifications() {
        passwordManagerNotificationCancellable = NotificationCenter.default.publisher(for: .PasswordManagerChanged).sink { [weak self] _ in
            self?.updatePasswordManagementButton()
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
                  let topUrl = sender.userInfo?["topUrl"] as? URL,
                  let relativeTarget = self.addressBarViewController?.addressBarButtonsViewController?.privacyEntryPointButton
            else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.tabCollectionViewModel.selectedTabViewModel?.tab.url == topUrl else {
                          // if the tab is not active, don't show the popup
                          return
                      }

                let viewController = PopoverMessageViewController.createWithMessage(UserText.autoconsentPopoverMessage)
                viewController.show(onParent: self, relativeTo: relativeTarget)
            }
        }
    }

    func closeTransientPopovers() -> Bool {
        guard popovers.allSatisfy({ !$0.isShown }) else {
            return false
        }

        if bookmarkListPopover.isShown {
            bookmarkListPopover.close()
        }

        if passwordManagementPopover.isShown {
            passwordManagementPopover.close()
        }

        if downloadsPopover.isShown {
            downloadsPopover.close()
        }

        return true
    }

    func showBookmarkListPopover() {
        guard closeTransientPopovers() else { return }
        bookmarkListButton.isHidden = false
        if let tab = tabCollectionViewModel.selectedTabViewModel?.tab {
            bookmarkListPopover.viewController.currentTabWebsite = .init(tab)
        }
        bookmarkListPopover.show(relativeTo: bookmarkListButton.bounds.insetFromLineOfDeath(), of: bookmarkListButton, preferredEdge: .maxY)
        Pixel.fire(.bookmarksList(source: .button))
    }

    func showPasswordManagementPopover(sender: Any, selectedCategory: SecureVaultSorting.Category?) {
        guard closeTransientPopovers() else { return }
        passwordManagementButton.isHidden = false
        passwordManagementPopover.select(category: selectedCategory)
        passwordManagementPopover.show(relativeTo: passwordManagementButton.bounds.insetFromLineOfDeath(),
                                       of: passwordManagementButton,
                                       preferredEdge: .minY)
        Pixel.fire(.manageLogins(source: sender is NSButton ? .button : (sender is MainMenu ? .mainMenu : .moreMenu)))
    }

    func toggleDownloadsPopover(keepButtonVisible: Bool, shouldFirePixel: Bool = true) {
        if downloadsPopover.isShown {
            downloadsPopover.close()
            return
        }
        guard closeTransientPopovers(),
              downloadsButton.window != nil
        else { return }

        downloadsButton.isHidden = false
        if keepButtonVisible {
            setDownloadButtonHidingTimer()
        }
        downloadsPopover.show(relativeTo: downloadsButton.bounds.insetFromLineOfDeath(), of: downloadsButton, preferredEdge: .maxY)

        if shouldFirePixel {
            Pixel.fire(.manageDownloads(source: .button))
        }
    }

    private var downloadsPopoverTimer: Timer?
    private func showDownloadsPopoverAndAutoHide() {
        let timerBlock: (Timer) -> Void = { [weak self] _ in
            self?.downloadsPopoverTimer?.invalidate()
            self?.downloadsPopoverTimer = nil

            if self?.downloadsPopover.isShown ?? false {
                self?.downloadsPopover.close()
            }
        }

        if !self.downloadsPopover.isShown {
            self.toggleDownloadsPopover(keepButtonVisible: true, shouldFirePixel: false)

            downloadsPopoverTimer = Timer.scheduledTimer(withTimeInterval: Constants.downloadsPopoverAutoHidingInterval,
                                                         repeats: false,
                                                         block: timerBlock)
        }
    }

    private func setupNavigationButtonMenus() {
        let backButtonMenu = NSMenu()
        backButtonMenu.delegate = goBackButtonMenuDelegate
        goBackButton.menu = backButtonMenu
        let forwardButtonMenu = NSMenu()
        forwardButtonMenu.delegate = goForwardButtonMenuDelegate
        goForwardButton.menu = forwardButtonMenu
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
        bottom?.constant = homePage ? 0 : verticalPadding

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
                    self.showDownloadsPopoverAndAutoHide()
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

    private func updatePasswordManagementButton() {
        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url

        passwordManagementButton.image = NSImage(named: "PasswordManagement")

        if popovers.contains(where: { $0.isShown }) {
            return
        }

        if passwordManagementPopover.viewController.isDirty {
            passwordManagementButton.image = NSImage(named: "PasswordManagementDirty")
            return
        }

        passwordManagementButton.isHidden = !passwordManagementPopover.isShown

        passwordManagementPopover.viewController.domain = nil
        guard let url = url, let domain = url.host else {
            return
        }
        passwordManagementPopover.viewController.domain = domain
    }

    private func updateDownloadsButton() {
        let hasActiveDownloads = DownloadListCoordinator.shared.hasActiveDownloads
        downloadsButton.image = hasActiveDownloads ? Self.activeDownloadsImage : Self.inactiveDownloadsImage
        let isTimerActive = downloadsButtonHidingTimer != nil

        downloadsButton.isHidden = !(hasActiveDownloads || isTimerActive)

        if !downloadsButton.isHidden { setDownloadButtonHidingTimer() }
        downloadsButton.isMouseDown = downloadsPopover.isShown
    }

    private var downloadsButtonHidingTimer: Timer?
    private func setDownloadButtonHidingTimer() {
        guard downloadsButtonHidingTimer == nil else { return }

        let timerBlock: (Timer) -> Void = { [weak self] _ in
            guard let self = self else { return }

            self.invalideDownloadButtonHidingTimer()
            self.hideDownloadButtonIfPossible()
        }

        downloadsButtonHidingTimer = Timer.scheduledTimer(withTimeInterval: Constants.downloadsButtonAutoHidingInterval,
                                                          repeats: false,
                                                          block: timerBlock)
    }

    private func invalideDownloadButtonHidingTimer() {
        self.downloadsButtonHidingTimer?.invalidate()
        self.downloadsButtonHidingTimer = nil
    }

    private func hideDownloadButtonIfPossible() {
        if DownloadListCoordinator.shared.hasActiveDownloads || self.downloadsPopover.isShown { return }

        downloadsButton.isHidden = true
    }

    private func updateBookmarksButton() {
        bookmarkListButton.isHidden = !bookmarkListPopover.isShown
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
            showSaveCredentialsPopover()
            saveCredentialsPopover.viewController.update(credentials: credentials, automaticallySaved: data.automaticallySavedCredentials)
        } else if autofillPreferences.askToSavePaymentMethods, let card = data.creditCard {
            os_log("Presenting Save Payment Method popover", log: .passwordManager)
            showSavePaymentMethodPopover()
            savePaymentMethodPopover.viewController.savePaymentMethod(card)
        } else if autofillPreferences.askToSaveAddresses, let identity = data.identity {
            os_log("Presenting Save Identity popover", log: .passwordManager)
            showSaveIdentityPopover()
            saveIdentityPopover.viewController.saveIdentity(identity)
        } else {
            os_log("Received save autofill data call, but there was no data to present", log: .passwordManager)
        }
    }

    private func showSaveCredentialsPopover() {
        show(popover: saveCredentialsPopover)
    }

    private func showSavePaymentMethodPopover() {
        show(popover: savePaymentMethodPopover)
    }

    private func showSaveIdentityPopover() {
        show(popover: saveIdentityPopover)
    }

    private func show(popover: NSPopover) {
        passwordManagementButton.isHidden = false
        popover.show(relativeTo: passwordManagementButton.bounds.insetFromLineOfDeath(),
                     of: passwordManagementButton,
                     preferredEdge: .minY)
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
// swiftlint:enable type_body_length

extension NavigationBarViewController: OptionsButtonMenuDelegate {

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu) {
        showBookmarkListPopover()
    }

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category) {
        showPasswordManagementPopover(sender: menu, selectedCategory: selectedCategory)
    }

    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu) {
        toggleDownloadsPopover(keepButtonVisible: false)
    }

    func optionsButtonMenuRequestedPrint(_ menu: NSMenu) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.printWebView(self)
    }

}

extension NavigationBarViewController: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        if notification.object as AnyObject? === downloadsPopover {
            updateDownloadsButton()
            downloadsPopoverTimer?.invalidate()
            downloadsPopoverTimer = nil
        } else if notification.object as AnyObject? === bookmarkListPopover {
            updateBookmarksButton()
        } else if popovers.contains(where: { notification.object as AnyObject? === $0 }) {
            updatePasswordManagementButton()
        }
    }

}

extension NavigationBarViewController: DownloadsViewControllerDelegate {

    func clearDownloadsActionTriggered() {
        invalideDownloadButtonHidingTimer()
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
        
        showSaveCredentialsPopover()
        saveCredentialsPopover.viewController.update(credentials: mockCredentials, automaticallySaved: false)
    }
    
    fileprivate func showMockCredentialsSavedPopover() {
        let account = SecureVaultModels.WebsiteAccount(title: nil, username: "example-username", domain: "example.com")
        let mockCredentials = SecureVaultModels.WebsiteCredentials(account: account, password: "password".data(using: .utf8)!)
        
        showSaveCredentialsPopover()
        saveCredentialsPopover.viewController.update(credentials: mockCredentials, automaticallySaved: true)
    }
    
}
#endif
