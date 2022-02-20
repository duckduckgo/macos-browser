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

// swiftlint:disable type_body_length
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
    @IBOutlet weak var daxLogo: NSView!
    @IBOutlet weak var addressBarContainer: NSView!

    @IBOutlet var addressBarLeftToNavButtonsConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarLeftToSuperviewConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarProportionalWidthConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarTopConstraint: NSLayoutConstraint!

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

        animateBar(tabCollectionViewModel.selectedTabViewModel?.tab.content == .homepage, animated: false)
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
            addressBarLeftToSuperviewConstraint.isActive = true
            addressBarLeftToNavButtonsConstraint.isActive = false
            addressBarProportionalWidthConstraint.isActive = false
        } else {
            addressBarLeftToSuperviewConstraint.isActive = false
            addressBarLeftToNavButtonsConstraint.isActive = true
            addressBarProportionalWidthConstraint.isActive = true
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

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.goForward()
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
        showPasswordManagementPopover(sender: sender)
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

    func closeTransientPopovers() -> Bool {
        guard !saveCredentialsPopover.isShown else {
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
        bookmarkListPopover.show(relativeTo: bookmarkListButton.bounds.insetFromLineOfDeath(), of: bookmarkListButton, preferredEdge: .maxY)
        Pixel.fire(.bookmarksList(source: .button))
    }

    func showPasswordManagementPopover(sender: Any) {
        guard closeTransientPopovers() else { return }
        passwordManagementButton.isHidden = false
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
            self?.subscribeToTabUrl()
        }
    }

    private func subscribeToTabUrl() {
        urlCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.$content
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] content in
                self?.updatePasswordManagementButton()
                self?.animateBar(content == .homepage)
                if content == .homepage {
                    self?.addressBarViewController?.addressBarTextField.becomeFirstResponder()
                }
            })
    }

    private func animateBar(_ homepage: Bool, animated: Bool = true) {
        let performAnim = animated

        let top = performAnim ? addressBarTopConstraint.animator() : addressBarTopConstraint
        top?.constant = homepage ? 16 : 6

        let width = performAnim ? addressBarProportionalWidthConstraint.animator() : addressBarProportionalWidthConstraint
        width?.constant = homepage ? -260 : 0

//        let image = performAnim ? daxLogo.animator() : daxLogo
//        image?.alphaValue = homepage ? 1 : 0

//        let buttons = performAnim ? navigationButtons.animator() : navigationButtons
//        buttons?.isHidden = homepage
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
            .weakAssign(to: \.progress, on: downloadsProgressView)
            .store(in: &downloadsCancellables)
    }

    private func updatePasswordManagementButton() {
        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url

        passwordManagementButton.image = NSImage(named: "PasswordManagement")

        if saveCredentialsPopover.isShown {
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
        credentialsToSaveCancellable = tabCollectionViewModel.selectedTabViewModel?.$credentialsToSave
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in
                if let credentials = $0 {
                    self?.promptToSaveCredentials(credentials)
                    self?.tabCollectionViewModel.selectedTabViewModel?.credentialsToSave = nil
                }
        })
    }

    private func promptToSaveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        showSaveCredentialsPopover()
        saveCredentialsPopover.viewController.saveCredentials(credentials)
    }

    private func showSaveCredentialsPopover() {
        passwordManagementButton.isHidden = false

        saveCredentialsPopover.show(relativeTo: passwordManagementButton.bounds.insetFromLineOfDeath(),
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

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu) {
        showPasswordManagementPopover(sender: menu)
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
        } else if notification.object as AnyObject? === saveCredentialsPopover {
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
