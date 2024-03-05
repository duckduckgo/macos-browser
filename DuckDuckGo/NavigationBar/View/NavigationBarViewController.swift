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
import Common
import BrowserServicesKit

#if NETWORK_PROTECTION
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
#endif

#if SUBSCRIPTION
import Subscription
import SubscriptionUI
#endif

// swiftlint:disable:next type_body_length
final class NavigationBarViewController: NSViewController {

    enum Constants {
        static let downloadsButtonAutoHidingInterval: TimeInterval = 5 * 60
        static let homeButtonSeparatorSpacing: CGFloat = 12
        static let homeButtonSeparatorHeight: CGFloat = 20
    }

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshOrStopButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var bookmarkListButton: MouseOverButton!
    @IBOutlet weak var passwordManagementButton: MouseOverButton!
    @IBOutlet weak var homeButton: MouseOverButton!
    @IBOutlet weak var homeButtonSeparator: NSBox!
    @IBOutlet weak var downloadsButton: MouseOverButton!
    @IBOutlet weak var networkProtectionButton: MouseOverButton!
    @IBOutlet weak var navigationButtons: NSStackView!
    @IBOutlet weak var addressBarContainer: NSView!
    @IBOutlet weak var daxLogo: NSImageView!
    @IBOutlet weak var addressBarStack: NSStackView!

    @IBOutlet var addressBarLeftToNavButtonsConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarProportionalWidthConstraint: NSLayoutConstraint!
    @IBOutlet var navigationBarButtonsLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarTopConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarBottomConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet var buttonsTopConstraint: NSLayoutConstraint!
    @IBOutlet var logoWidthConstraint: NSLayoutConstraint!

    private let downloadListCoordinator: DownloadListCoordinator

    lazy var downloadsProgressView: CircularProgressView = {
        let bounds = downloadsButton.bounds
        let width: CGFloat = 27.0
        let frame = NSRect(x: (bounds.width - width) * 0.5, y: (bounds.height - width) * 0.5, width: width, height: width)
        let progressView = CircularProgressView(frame: frame)
        downloadsButton.addSubview(progressView)
        return progressView
    }()

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel
    private let isBurner: Bool

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private var popovers: NavigationBarPopovers

    var isDownloadsPopoverShown: Bool {
        popovers.isDownloadsPopoverShown
    }
    var isAutoFillAutosaveMessageVisible: Bool = false

    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var credentialsToSaveCancellable: AnyCancellable?
    private var vpnToggleCancellable: AnyCancellable?
    private var passwordManagerNotificationCancellable: AnyCancellable?
    private var pinnedViewsNotificationCancellable: AnyCancellable?
    private var navigationButtonsCancellables = Set<AnyCancellable>()
    private var downloadsCancellables = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .homeButtonPosition, defaultValue: .right)
    static private var homeButtonPosition: HomeButtonPosition
    static private let homeButtonTag = 3
    static private let homeButtonLeftPosition = 0

#if NETWORK_PROTECTION
    private let networkProtectionButtonModel: NetworkProtectionNavBarButtonModel
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
#endif

#if NETWORK_PROTECTION
    static func create(tabCollectionViewModel: TabCollectionViewModel, isBurner: Bool, networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(), downloadListCoordinator: DownloadListCoordinator = .shared) -> NavigationBarViewController {
        NSStoryboard(name: "NavigationBar", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, isBurner: isBurner, networkProtectionFeatureActivation: networkProtectionFeatureActivation, downloadListCoordinator: downloadListCoordinator)
        }!
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, isBurner: Bool, networkProtectionFeatureActivation: NetworkProtectionFeatureActivation, downloadListCoordinator: DownloadListCoordinator) {

        let vpnBundleID = Bundle.main.vpnMenuAgentBundleId
        let ipcClient = TunnelControllerIPCClient(machServiceName: vpnBundleID)
        ipcClient.register()

        let networkProtectionPopoverManager = NetworkProtectionNavBarPopoverManager(ipcClient: ipcClient)

        self.popovers = NavigationBarPopovers(networkProtectionPopoverManager: networkProtectionPopoverManager)
        self.tabCollectionViewModel = tabCollectionViewModel
        self.networkProtectionButtonModel = NetworkProtectionNavBarButtonModel(popoverManager: networkProtectionPopoverManager)
        self.isBurner = isBurner
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.downloadListCoordinator = downloadListCoordinator
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }
#else
    static func create(tabCollectionViewModel: TabCollectionViewModel, isBurner: Bool, downloadListCoordinator: DownloadListCoordinator = .shared) -> NavigationBarViewController {
        NSStoryboard(name: "NavigationBar", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, isBurner: isBurner, downloadListCoordinator: downloadListCoordinator)
        }!
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, isBurner: Bool, downloadListCoordinator: DownloadListCoordinator) {
        self.popovers = NavigationBarPopovers()
        self.tabCollectionViewModel = tabCollectionViewModel
        self.isBurner = isBurner
        self.downloadListCoordinator = downloadListCoordinator
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }
#endif

    required init?(coder: NSCoder) {
        fatalError("NavigationBarViewController: Bad initializer")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.masksToBounds = false
        addressBarContainer.wantsLayer = true
        addressBarContainer.layer?.masksToBounds = false

        setupNavigationButtonMenus()
        subscribeToSelectedTabViewModel()
#if NETWORK_PROTECTION
        listenToVPNToggleNotifications()
#endif
        listenToPasswordManagerNotifications()
        listenToPinningManagerNotifications()
        listenToMessageNotifications()
        subscribeToDownloads()
        addContextMenu()

        optionsButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.sendAction(on: .leftMouseDown)
        downloadsButton.sendAction(on: .leftMouseDown)
        networkProtectionButton.sendAction(on: .leftMouseDown)
        passwordManagementButton.sendAction(on: .leftMouseDown)

        optionsButton.toolTip = UserText.applicationMenuTooltip
        optionsButton.setAccessibilityIdentifier("Options Button")

        networkProtectionButton.toolTip = UserText.networkProtectionButtonTooltip

#if NETWORK_PROTECTION
        setupNetworkProtectionButton()
#endif

#if DEBUG || REVIEW
        addDebugNotificationListeners()
#endif
    }

    override func viewWillAppear() {
        updateDownloadsButton()
        updatePasswordManagementButton()
        updateBookmarksButton()
        updateHomeButton()

        if view.window?.isPopUpWindow == true {
            goBackButton.isHidden = true
            goForwardButton.isHidden = true
            refreshOrStopButton.isHidden = true
            optionsButton.isHidden = true
            homeButton.isHidden = true
            homeButtonSeparator.isHidden = true
            addressBarTopConstraint.constant = 0
            addressBarBottomConstraint.constant = 0
            addressBarLeftToNavButtonsConstraint.isActive = false
            addressBarProportionalWidthConstraint.isActive = false
            navigationBarButtonsLeadingConstraint.isActive = false

            // This pulls the dashboard button to the left for the popup
            NSLayoutConstraint.activate(addressBarStack.addConstraints(to: view, [
                .leading: .leading(multiplier: 1.0, const: 72)
            ]))
        }
    }

    @IBSegueAction func createAddressBarViewController(_ coder: NSCoder) -> AddressBarViewController? {
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel,
                                                                      isBurner: isBurner) else {
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
           // don‘t open a new tab when the window is cmd-clicked in background
           sender.window?.isKeyWindow == true && NSApp.isActive,
           let backItem = selectedTabViewModel.tab.webView.backForwardList.backItem {
            openBackForwardHistoryItemInNewChildTab(with: backItem.url)
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
           // don‘t open a new tab when the window is cmd-clicked in background
           sender.window?.isKeyWindow == true && NSApp.isActive,
           let forwardItem = selectedTabViewModel.tab.webView.backForwardList.forwardItem {
            openBackForwardHistoryItemInNewChildTab(with: forwardItem.url)
        } else {
            selectedTabViewModel.tab.goForward()
        }
    }

    private func openBackForwardHistoryItemInNewChildTab(with url: URL) {
        let tab = Tab(content: .url(url, source: .historyEntry), parentTab: tabCollectionViewModel.selectedTabViewModel?.tab, shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.insert(tab, selected: false)
    }

    @IBAction func refreshOrStopAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        if selectedTabViewModel.isLoading {
            selectedTabViewModel.tab.stopLoading()
        } else {
            selectedTabViewModel.reload()
        }
    }

    @IBAction func homeButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }
        selectedTabViewModel.tab.openHomePage()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        let internalUserDecider = NSApp.delegateTyped.internalUserDecider
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: PasswordManagerCoordinator.shared,
                                   internalUserDecider: internalUserDecider)
        menu.actionDelegate = self
        let location = NSPoint(x: -menu.size.width + sender.bounds.width, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: sender)
    }

    @IBAction func bookmarksButtonAction(_ sender: NSButton) {
        popovers.bookmarksButtonPressed(anchorView: bookmarkListButton,
                                        popoverDelegate: self,
                                        tab: tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @IBAction func passwordManagementButtonAction(_ sender: NSButton) {
        popovers.passwordManagementButtonPressed(usingView: passwordManagementButton, withDelegate: self)
    }

#if NETWORK_PROTECTION
    @IBAction func networkProtectionButtonAction(_ sender: NSButton) {
        toggleNetworkProtectionPopover()
    }

    private func toggleNetworkProtectionPopover() {
        let featureVisibility = DefaultNetworkProtectionVisibility()
        guard featureVisibility.isNetworkProtectionVisible() else {
            featureVisibility.disableForWaitlistUsers()
            LocalPinningManager.shared.unpin(.networkProtection)
            return
        }

        #if SUBSCRIPTION
        if DefaultSubscriptionFeatureAvailability().isFeatureAvailable() {
            let accountManager = AccountManager()
            let networkProtectionTokenStorage = NetworkProtectionKeychainTokenStore()

            if accountManager.accessToken != nil && (try? networkProtectionTokenStorage.fetchToken()) == nil {
                print("[NetP Subscription] Got access token but not auth token, meaning token exchange failed")
                return
            }
        }
        #endif

        // 1. If the user is on the waitlist but hasn't been invited or accepted terms and conditions, show the waitlist screen.
        // 2. If the user has no waitlist state but has an auth token, show the NetP popover.
        // 3. If the user has no state of any kind, show the waitlist screen.

        if NetworkProtectionWaitlist().shouldShowWaitlistViewController {
            NetworkProtectionWaitlistViewControllerPresenter.show()
            DailyPixel.fire(pixel: .networkProtectionWaitlistIntroDisplayed, frequency: .dailyAndCount, includeAppVersionParameter: true)
        } else if NetworkProtectionKeychainTokenStore().isFeatureActivated {
            popovers.toggleNetworkProtectionPopover(usingView: networkProtectionButton, withDelegate: networkProtectionButtonModel)
        } else {
            NetworkProtectionWaitlistViewControllerPresenter.show()
            DailyPixel.fire(pixel: .networkProtectionWaitlistIntroDisplayed, frequency: .dailyAndCount, includeAppVersionParameter: true)
        }
    }
#endif

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

#if NETWORK_PROTECTION
    func listenToVPNToggleNotifications() {
        vpnToggleCancellable = NotificationCenter.default.publisher(for: .ToggleNetworkProtectionInMainWindow).receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard self?.view.window?.isKeyWindow == true else {
                return
            }

            self?.toggleNetworkProtectionPopover()
        }
    }
#endif

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
                case .homeButton:
                    self.updateHomeButton()
#if NETWORK_PROTECTION
                case .networkProtection:
                    networkProtectionButtonModel.updateVisibility()
#endif
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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showLoginAutosavedFeedback(_:)),
                                               name: .loginAutoSaved,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showAutoconsentFeedback(_:)),
                                               name: AutoconsentUserScript.newSitePopupHiddenNotification,
                                               object: nil)

#if NETWORK_PROTECTION
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showVPNUninstalledFeedback(_:)),
                                               name: NetworkProtectionFeatureDisabler.vpnUninstalledNotificationName,
                                               object: nil)
#endif
    }

    @objc private func showVPNUninstalledFeedback(_ sender: Notification) {
        guard view.window?.isKeyWindow == true else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController(message: "Network Protection was uninstalled")
            viewController.show(onParent: self, relativeTo: self.optionsButton)
        }
    }

    @objc private func showPrivateEmailCopiedToClipboard(_ sender: Notification) {
        guard view.window?.isKeyWindow == true else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController(message: UserText.privateEmailCopiedToClipboard)
            viewController.show(onParent: self, relativeTo: self.optionsButton)
        }
    }

    @objc private func showFireproofingFeedback(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
              let domain = sender.userInfo?[FireproofDomains.Constants.newFireproofDomainKey] as? String else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController(message: UserText.domainIsFireproof(domain: domain))
            viewController.show(onParent: self, relativeTo: self.optionsButton)
        }
    }

    @objc private func showLoginAutosavedFeedback(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
              let account = sender.object as? SecureVaultModels.WebsiteAccount else { return }

        guard let domain = account.domain else {
            return
        }

        DispatchQueue.main.async {

            let action = {
                self.showPasswordManagerPopover(selectedWebsiteAccount: account)
            }
            let popoverMessage = PopoverMessageViewController(message: UserText.passwordManagerAutosavePopoverText(domain: domain),
                                                              image: .passwordManagement,
                                                              buttonText: UserText.passwordManagerAutosaveButtonText,
                                                              buttonAction: action,
                                                              onDismiss: {
                                                                    self.isAutoFillAutosaveMessageVisible = false
                                                                    self.passwordManagementButton.isHidden = !LocalPinningManager.shared.isPinned(.autofill)
            }
                                                              )
            self.isAutoFillAutosaveMessageVisible = true
            self.passwordManagementButton.isHidden = false
            popoverMessage.show(onParent: self, relativeTo: self.passwordManagementButton)
        }
    }

    @objc private func showAutoconsentFeedback(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
              let topUrl = sender.userInfo?["topUrl"] as? URL,
              let isCosmetic = sender.userInfo?["isCosmetic"] as? Bool
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.tabCollectionViewModel.selectedTabViewModel?.tab.url == topUrl else {
                return // if the tab is not active, don't show the popup
            }
            let animationType: NavigationBarBadgeAnimationView.AnimationType = isCosmetic ? .cookiePopupHidden : .cookiePopupManaged
            self.addressBarViewController?.addressBarButtonsViewController?.showBadgeNotification(animationType)
        }
    }

    func toggleDownloadsPopover(keepButtonVisible: Bool) {

        downloadsButton.isHidden = false
        if keepButtonVisible {
            setDownloadButtonHidingTimer()
        }

        popovers.toggleDownloadsPopover(usingView: downloadsButton, popoverDelegate: self, downloadsDelegate: self)
    }

    func showPasswordManagerPopover(selectedCategory: SecureVaultSorting.Category?) {
        popovers.showPasswordManagementPopover(selectedCategory: selectedCategory,
                                               usingView: passwordManagementButton,
                                               withDelegate: self)
    }

    func showPasswordManagerPopover(selectedWebsiteAccount: SecureVaultModels.WebsiteAccount) {
        popovers.showPasswordManagerPopover(selectedWebsiteAccount: selectedWebsiteAccount,
                                                     usingView: passwordManagementButton,
                                                     withDelegate: self)
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
        refreshOrStopButton.toolTip = UserText.refreshPageTooltip
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

    enum AddressBarSizeClass {
        case `default`
        case homePage
        case popUpWindow

        fileprivate var height: CGFloat {
            switch self {
            case .homePage: 52
            case .popUpWindow: 42
            case .default: 48
            }
        }

        fileprivate var topPadding: CGFloat {
            switch self {
            case .homePage: 16
            case .popUpWindow: 0
            case .default: 6
            }
        }

        fileprivate var bottomPadding: CGFloat {
            switch self {
            case .homePage: 2
            case .popUpWindow: 0
            case .default: 6
            }
        }

        fileprivate var logoWidth: CGFloat {
            switch self {
            case .homePage: 44
            case .popUpWindow, .default: 0
            }
        }

        fileprivate var isLogoVisible: Bool {
            switch self {
            case .homePage: true
            case .popUpWindow, .default: false
            }
        }
    }

    private var daxFadeInAnimation: DispatchWorkItem?
    private var heightChangeAnimation: DispatchWorkItem?
    func resizeAddressBar(for sizeClass: AddressBarSizeClass, animated: Bool) {
        daxFadeInAnimation?.cancel()
        heightChangeAnimation?.cancel()

        daxLogo.alphaValue = !sizeClass.isLogoVisible ? 1 : 0 // initial value to animate from

        let performResize = { [weak self] in
            guard let self else { return }

            let height: NSLayoutConstraint = animated ? addressBarHeightConstraint.animator() : addressBarHeightConstraint
            height.constant = sizeClass.height

            let barTop: NSLayoutConstraint = animated ? addressBarTopConstraint.animator() : addressBarTopConstraint
            barTop.constant = sizeClass.topPadding

            let bottom: NSLayoutConstraint = animated ? addressBarBottomConstraint.animator() : addressBarBottomConstraint
            bottom.constant = sizeClass.bottomPadding

            let logoWidth: NSLayoutConstraint = animated ? logoWidthConstraint.animator() : logoWidthConstraint
            logoWidth.constant = sizeClass.logoWidth
        }

        let heightChange: DispatchWorkItem
        if animated {
            heightChange = DispatchWorkItem {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.1
                    performResize()
                }
            }
            let fadeIn = DispatchWorkItem { [weak self] in
                guard let self else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    self.daxLogo.alphaValue = sizeClass.isLogoVisible ? 1 : 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: fadeIn)
            self.daxFadeInAnimation = fadeIn
        } else {
            daxLogo.alphaValue = sizeClass.isLogoVisible ? 1 : 0
            heightChange = DispatchWorkItem {
                performResize()
            }
        }
        DispatchQueue.main.async(execute: heightChange)
        self.heightChangeAnimation = heightChange
    }

    private func subscribeToDownloads() {
        downloadListCoordinator.updates
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] update in
                guard let self else { return }

                let shouldShowPopover = update.kind == .updated
                    && DownloadsPreferences().shouldOpenPopupOnCompletion
                    && update.item.destinationURL != nil
                    && update.item.tempURL == nil
                    && !update.item.isBurner
                    && WindowControllersManager.shared.lastKeyMainWindowController?.window === downloadsButton.window

                if shouldShowPopover {
                    self.popovers.showDownloadsPopoverAndAutoHide(usingView: downloadsButton,
                                                                  popoverDelegate: self,
                                                                  downloadsDelegate: self)
                } else {
                    if update.item.isBurner {
                        invalidateDownloadButtonHidingTimer()
                        updateDownloadsButton(updatingFromPinnedViewsNotification: false)
                    }
                }
                updateDownloadsButton()
            }
            .store(in: &downloadsCancellables)
        downloadListCoordinator.progress
            .publisher(for: \.fractionCompleted)
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .map { [downloadListCoordinator] _ in
                let progress = downloadListCoordinator.progress
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
        let title = LocalPinningManager.shared.shortcutTitle(for: .autofill)
        menu.addItem(withTitle: title, action: #selector(toggleAutofillPanelPinning), keyEquivalent: "")

        passwordManagementButton.menu = menu
        passwordManagementButton.toolTip = UserText.autofillShortcutTooltip

        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url

        passwordManagementButton.image = .passwordManagement

        if popovers.hasAnySavePopoversVisible() {
            return
        }

        if popovers.isPasswordManagementDirty {
            passwordManagementButton.image = .passwordManagementDirty
            return
        }

        if LocalPinningManager.shared.isPinned(.autofill) {
            passwordManagementButton.isHidden = false
        } else {
            passwordManagementButton.isHidden = !popovers.isPasswordManagementPopoverShown && !isAutoFillAutosaveMessageVisible
        }

        popovers.passwordManagementDomain = nil
        guard let url = url, let domain = url.host else {
            return
        }
        popovers.passwordManagementDomain = domain
    }

    private func updateHomeButton() {
        let menu = NSMenu()

        homeButton.menu = menu
        homeButton.toolTip = UserText.homeButtonTooltip

        if LocalPinningManager.shared.isPinned(.homeButton) {
            homeButton.isHidden = false

            if let homeButtonView = navigationButtons.arrangedSubviews.first(where: { $0.tag == Self.homeButtonTag }) {
                navigationButtons.removeArrangedSubview(homeButtonView)
                if Self.homeButtonPosition == .left {
                    navigationButtons.insertArrangedSubview(homeButtonView, at: Self.homeButtonLeftPosition)
                    homeButtonSeparator.isHidden = false

                    // Set spacing/size for the separator
                    navigationButtons.setCustomSpacing(Constants.homeButtonSeparatorSpacing, after: navigationButtons.views[0])
                    navigationButtons.setCustomSpacing(Constants.homeButtonSeparatorSpacing, after: navigationButtons.views[1])
                    homeButtonSeparator.heightAnchor.constraint(equalToConstant: Constants.homeButtonSeparatorHeight).isActive = true
                    homeButtonSeparator.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([NSLayoutConstraint(item: homeButtonSeparator as Any,
                                                                        attribute: .centerY,
                                                                        relatedBy: .equal,
                                                                        toItem: navigationButtons,
                                                                        attribute: .centerY,
                                                                        multiplier: 1,
                                                                        constant: 0)])
                } else {
                    navigationButtons.insertArrangedSubview(homeButtonView, at: navigationButtons.arrangedSubviews.count)
                    homeButtonSeparator.isHidden = true
                }
            }
        } else {
            homeButton.isHidden = true
            homeButtonSeparator.isHidden = true
        }
    }

    private func updateDownloadsButton(updatingFromPinnedViewsNotification: Bool = false) {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.shortcutTitle(for: .downloads)
        menu.addItem(withTitle: title, action: #selector(toggleDownloadsPanelPinning(_:)), keyEquivalent: "")

        downloadsButton.menu = menu
        downloadsButton.toolTip = UserText.downloadsShortcutTooltip

        if LocalPinningManager.shared.isPinned(.downloads) {
            downloadsButton.isHidden = false
            return
        }

        let hasActiveDownloads = downloadListCoordinator.hasActiveDownloads
        downloadsButton.image = hasActiveDownloads ? .downloadsActive : .downloads
        let isTimerActive = downloadsButtonHidingTimer != nil

        if popovers.isDownloadsPopoverShown {
            downloadsButton.isHidden = false
        } else {
            downloadsButton.isHidden = !(hasActiveDownloads || isTimerActive)
        }

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
            downloadListCoordinator.hasActiveDownloads ||
            popovers.isDownloadsPopoverShown { return }

        downloadsButton.isHidden = true
    }

    private func updateBookmarksButton() {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.shortcutTitle(for: .bookmarks)
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
        credentialsToSaveCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.autofillDataToSavePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let self, let data else { return }
                self.promptToSaveAutofillData(data)
                self.tabCollectionViewModel.selectedTabViewModel?.tab.resetAutofillData()
            }
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
        navigationButtonsCancellables.removeAll()
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        selectedTabViewModel.$canGoBack
            .removeDuplicates()
            .assign(to: \.isEnabled, onWeaklyHeld: goBackButton)
            .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canGoForward
            .removeDuplicates()
            .assign(to: \.isEnabled, onWeaklyHeld: goForwardButton)
            .store(in: &navigationButtonsCancellables)

        Publishers.CombineLatest(selectedTabViewModel.$canReload, selectedTabViewModel.$isLoading)
            .map({
                $0.canReload || $0.isLoading
            } as ((canReload: Bool, isLoading: Bool)) -> Bool)
            .removeDuplicates()
            .assign(to: \.isEnabled, onWeaklyHeld: refreshOrStopButton)
            .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$isLoading
            .removeDuplicates()
            .sink { [weak refreshOrStopButton] isLoading in
                refreshOrStopButton?.image = isLoading ? .stop : .refresh
                refreshOrStopButton?.toolTip = isLoading ? UserText.stopLoadingTooltip : UserText.refreshPageTooltip
            }
            .store(in: &navigationButtonsCancellables)
    }
}

extension NavigationBarViewController: NSMenuDelegate {

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        BookmarksBarMenuFactory.addToMenu(menu)

        menu.addItem(NSMenuItem.separator())

        HomeButtonMenuFactory.addToMenu(menu)

        let autofillTitle = LocalPinningManager.shared.shortcutTitle(for: .autofill)
        menu.addItem(withTitle: autofillTitle, action: #selector(toggleAutofillPanelPinning), keyEquivalent: "A")

        let bookmarksTitle = LocalPinningManager.shared.shortcutTitle(for: .bookmarks)
        menu.addItem(withTitle: bookmarksTitle, action: #selector(toggleBookmarksPanelPinning), keyEquivalent: "K")

        let downloadsTitle = LocalPinningManager.shared.shortcutTitle(for: .downloads)
        menu.addItem(withTitle: downloadsTitle, action: #selector(toggleDownloadsPanelPinning), keyEquivalent: "J")

#if NETWORK_PROTECTION
        let isPopUpWindow = view.window?.isPopUpWindow ?? false

        if !isPopUpWindow && networkProtectionFeatureActivation.isFeatureActivated {
            let networkProtectionTitle = LocalPinningManager.shared.shortcutTitle(for: .networkProtection)
            menu.addItem(withTitle: networkProtectionTitle, action: #selector(toggleNetworkProtectionPanelPinning), keyEquivalent: "N")
        }
#endif
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

    @objc
    private func toggleNetworkProtectionPanelPinning(_ sender: NSMenuItem) {
#if NETWORK_PROTECTION
        LocalPinningManager.shared.togglePinning(for: .networkProtection)
#endif
    }

    // MARK: - Network Protection

#if NETWORK_PROTECTION
    func showNetworkProtectionStatus() {
        let featureVisibility = DefaultNetworkProtectionVisibility()

        if featureVisibility.isNetworkProtectionVisible() {
            popovers.showNetworkProtectionPopover(positionedBelow: networkProtectionButton,
                                                  withDelegate: networkProtectionButtonModel)
        } else {
            featureVisibility.disableForWaitlistUsers()
        }
    }

    /// Sets up the Network Protection button.
    ///
    /// This method should be run just once during the lifecycle of this view.
    /// .
    private func setupNetworkProtectionButton() {
        assert(networkProtectionButton.menu == nil)

        let menuItem = NSMenuItem(title: LocalPinningManager.shared.shortcutTitle(for: .networkProtection), action: #selector(toggleNetworkProtectionPanelPinning), target: self)
        let menu = NSMenu(items: [menuItem])
        networkProtectionButton.menu = menu

        networkProtectionButtonModel.$shortcutTitle
            .receive(on: RunLoop.main)
            .sink { title in
                menuItem.title = title
            }
            .store(in: &cancellables)

        networkProtectionButtonModel.$showButton
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                let isPopUpWindow = self?.view.window?.isPopUpWindow ?? false
                self?.networkProtectionButton.isHidden =  isPopUpWindow || !show
            }
            .store(in: &cancellables)

        networkProtectionButtonModel.$buttonImage
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                self?.networkProtectionButton.image = image
            }
            .store(in: &cancellables)
    }
#endif

}

extension NavigationBarViewController: OptionsButtonMenuDelegate {

#if DBP
    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu) {
        WindowControllersManager.shared.showDataBrokerProtectionTab()
    }
#endif

    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu) {
        BWManager.shared.openBitwarden()
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

    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu) {
        WindowControllersManager.shared.showBookmarksTab()
    }

    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu) {
        DataImportView().show()
    }

    func optionsButtonMenuRequestedBookmarkExportInterface(_ menu: NSMenu) {
        NSApp.sendAction(#selector(AppDelegate.openExportBookmarks(_:)), to: nil, from: nil)
    }

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category) {
        popovers.showPasswordManagementPopover(selectedCategory: selectedCategory,
                                               usingView: passwordManagementButton,
                                               withDelegate: self)
    }

    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu) {
#if NETWORK_PROTECTION
        toggleNetworkProtectionPopover()
#else
        fatalError("Tried to open Network Protection when it was disabled")
#endif
    }

    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu) {
        toggleDownloadsPopover(keepButtonVisible: false)
    }

    func optionsButtonMenuRequestedPrint(_ menu: NSMenu) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.printWebView(self)
    }

    func optionsButtonMenuRequestedPreferences(_ menu: NSMenu) {
        WindowControllersManager.shared.showPreferencesTab()
    }

    func optionsButtonMenuRequestedAppearancePreferences(_ menu: NSMenu) {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .appearance)
    }

#if SUBSCRIPTION
    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu) {
        WindowControllersManager.shared.showTab(with: .subscription(.subscriptionPurchase))
    }

    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu) {
        WindowControllersManager.shared.showTab(with: .subscription(.identityTheftRestoration))
    }
#endif

}

// MARK: - NSPopoverDelegate

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
        NotificationCenter.default.publisher(for: .ShowSaveCredentialsPopover)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showMockSaveCredentialsPopover()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .ShowCredentialsSavedPopover)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showMockCredentialsSavedPopover()
            }
            .store(in: &cancellables)
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

#if NETWORK_PROTECTION
extension Notification.Name {
    static let ToggleNetworkProtectionInMainWindow = Notification.Name("com.duckduckgo.vpn.toggle-popover-in-main-window")
}
#endif
