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

import BrokenSitePrompt
import BrowserServicesKit
import Cocoa
import Combine
import Common
import Freemium
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import os.log
import PageRefreshMonitor
import PixelKit
import Subscription
import SubscriptionUI

final class NavigationBarViewController: NSViewController {

    enum Constants {
        static let downloadsButtonAutoHidingInterval: TimeInterval = 5 * 60
        static let maxDragDistanceToExpandHoveredFolder: CGFloat = 4
        static let dragOverFolderExpandDelay: TimeInterval = 0.3
    }

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshOrStopButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var bookmarkListButton: MouseOverButton!
    @IBOutlet weak var passwordManagementButton: MouseOverButton!
    @IBOutlet weak var homeButton: MouseOverButton!
    @IBOutlet weak var homeButtonSeparator: NSView!
    @IBOutlet weak var downloadsButton: MouseOverButton!
    @IBOutlet weak var networkProtectionButton: MouseOverButton!
    @IBOutlet weak var navigationButtons: NSStackView!
    @IBOutlet weak var addressBarContainer: NSView!
    @IBOutlet weak var daxLogo: NSImageView!
    @IBOutlet weak var addressBarStack: NSStackView!
    @IBOutlet weak var menuButtons: NSStackView!

    @IBOutlet weak var aiChatButton: MouseOverButton!
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

    private let dragDropManager: BookmarkDragDropManager

    private var subscriptionManager: SubscriptionManager {
        Application.appDelegate.subscriptionManager
    }

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel
    private var burnerMode: BurnerMode { tabCollectionViewModel.burnerMode }

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private var popovers: NavigationBarPopovers

    // used to show Bookmarks when dragging over the Bookmarks button
    private var dragDestination: (mouseLocation: NSPoint, hoverStarted: Date)?

    var isDownloadsPopoverShown: Bool {
        popovers.isDownloadsPopoverShown
    }
    var isAutoFillAutosaveMessageVisible: Bool = false

    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var credentialsToSaveCancellable: AnyCancellable?
    private var vpnToggleCancellable: AnyCancellable?
    private var feedbackFormCancellable: AnyCancellable?
    private var passwordManagerNotificationCancellable: AnyCancellable?
    private var pinnedViewsNotificationCancellable: AnyCancellable?
    private var navigationButtonsCancellables = Set<AnyCancellable>()
    private var downloadsCancellables = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()
    private let aiChatMenuConfig: AIChatMenuVisibilityConfigurable
    private let brokenSitePromptLimiter: BrokenSitePromptLimiter

    @UserDefaultsWrapper(key: .homeButtonPosition, defaultValue: .right)
    static private var homeButtonPosition: HomeButtonPosition
    static private let homeButtonTag = 3
    static private let homeButtonLeftPosition = 0

    private let networkProtectionButtonModel: NetworkProtectionNavBarButtonModel
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation

    static func create(tabCollectionViewModel: TabCollectionViewModel,
                       networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(),
                       downloadListCoordinator: DownloadListCoordinator = .shared,
                       dragDropManager: BookmarkDragDropManager = .shared,
                       networkProtectionPopoverManager: NetPPopoverManager,
                       networkProtectionStatusReporter: NetworkProtectionStatusReporter,
                       autofillPopoverPresenter: AutofillPopoverPresenter,
                       aiChatMenuConfig: AIChatMenuVisibilityConfigurable,
                       brokenSitePromptLimiter: BrokenSitePromptLimiter) -> NavigationBarViewController {
        NSStoryboard(name: "NavigationBar", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, networkProtectionFeatureActivation: networkProtectionFeatureActivation, downloadListCoordinator: downloadListCoordinator, dragDropManager: dragDropManager, networkProtectionPopoverManager: networkProtectionPopoverManager, networkProtectionStatusReporter: networkProtectionStatusReporter, autofillPopoverPresenter: autofillPopoverPresenter, aiChatMenuConfig: aiChatMenuConfig, brokenSitePromptLimiter: brokenSitePromptLimiter)
        }!
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, networkProtectionFeatureActivation: NetworkProtectionFeatureActivation, downloadListCoordinator: DownloadListCoordinator, dragDropManager: BookmarkDragDropManager, networkProtectionPopoverManager: NetPPopoverManager, networkProtectionStatusReporter: NetworkProtectionStatusReporter, autofillPopoverPresenter: AutofillPopoverPresenter,
          aiChatMenuConfig: AIChatMenuVisibilityConfigurable, brokenSitePromptLimiter: BrokenSitePromptLimiter) {

        self.popovers = NavigationBarPopovers(networkProtectionPopoverManager: networkProtectionPopoverManager, autofillPopoverPresenter: autofillPopoverPresenter, isBurner: tabCollectionViewModel.isBurner)
        self.tabCollectionViewModel = tabCollectionViewModel
        self.networkProtectionButtonModel = NetworkProtectionNavBarButtonModel(popoverManager: networkProtectionPopoverManager, statusReporter: networkProtectionStatusReporter)
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.downloadListCoordinator = downloadListCoordinator
        self.dragDropManager = dragDropManager
        self.aiChatMenuConfig = aiChatMenuConfig
        self.brokenSitePromptLimiter = brokenSitePromptLimiter
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }

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
        addContextMenu()

        optionsButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.registerForDraggedTypes(BookmarkDragDropManager.draggedTypes)
        bookmarkListButton.delegate = self
        bookmarkListButton.setAccessibilityIdentifier("NavigationBarViewController.bookmarkListButton")
        downloadsButton.sendAction(on: .leftMouseDown)
        downloadsButton.setAccessibilityIdentifier("NavigationBarViewController.downloadsButton")
        networkProtectionButton.sendAction(on: .leftMouseDown)
        passwordManagementButton.sendAction(on: .leftMouseDown)
        aiChatButton.sendAction(on: .leftMouseDown)

        optionsButton.toolTip = UserText.applicationMenuTooltip
        optionsButton.setAccessibilityIdentifier("NavigationBarViewController.optionsButton")

        networkProtectionButton.toolTip = UserText.networkProtectionButtonTooltip

        setupNetworkProtectionButton()

#if DEBUG || REVIEW
        addDebugNotificationListeners()
#endif

        subscribeToAIChatOnboarding()

#if !APPSTORE
        if #available(macOS 14.4, *), !burnerMode.isBurner {
            WebExtensionManager.shared.toolbarButtons().enumerated().forEach { (index, button) in
                menuButtons.insertArrangedSubview(button, at: index)
            }
        }
#endif
    }

    override func viewWillAppear() {
        subscribeToSelectedTabViewModel()
        listenToVPNToggleNotifications()
        listenToPasswordManagerNotifications()
        listenToPinningManagerNotifications()
        listenToMessageNotifications()
        listenToFeedbackFormNotifications()
        subscribeToDownloads()

        updateDownloadsButton(source: .default)
        updatePasswordManagementButton()
        updateBookmarksButton()
        updateHomeButton()
        updateAIChatButton()

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
        let onboardingPixelReporter = OnboardingPixelReporter()
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel,
                                                                      burnerMode: burnerMode,
                                                                      popovers: popovers,
                                                                      onboardingPixelReporter: onboardingPixelReporter) else {
            fatalError("NavigationBarViewController: Failed to init AddressBarViewController")
        }

        self.addressBarViewController = addressBarViewController
        return addressBarViewController
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.navigation.error("Selected tab view model is nil")
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
            Logger.navigation.error("Selected tab view model is nil")
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
            Logger.navigation.error("Selected tab view model is nil")
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
            Logger.navigation.error("Selected tab view model is nil")
            return
        }
        selectedTabViewModel.tab.openHomePage()
        PixelExperiment.fireOnboardingHomeButtonUsed5to7Pixel()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        let internalUserDecider = NSApp.delegateTyped.internalUserDecider
        let freemiumDBPFeature = Application.appDelegate.freemiumDBPFeature
        var dockCustomization: DockCustomization?
#if SPARKLE
        dockCustomization = Application.appDelegate.dockCustomization
#endif
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: PasswordManagerCoordinator.shared,
                                   vpnFeatureGatekeeper: DefaultVPNFeatureGatekeeper(subscriptionManager: subscriptionManager),
                                   internalUserDecider: internalUserDecider,
                                   subscriptionManager: subscriptionManager,
                                   freemiumDBPFeature: freemiumDBPFeature,
                                   dockCustomizer: dockCustomization)

        menu.actionDelegate = self
        let location = NSPoint(x: -menu.size.width + sender.bounds.width, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: sender)
    }

    @IBAction func bookmarksButtonAction(_ sender: NSButton) {
        popovers.bookmarksButtonPressed(bookmarkListButton, popoverDelegate: self, tab: tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @IBAction func passwordManagementButtonAction(_ sender: NSButton) {
        popovers.passwordManagementButtonPressed(passwordManagementButton, withDelegate: self)
    }

    @IBAction func networkProtectionButtonAction(_ sender: NSButton) {
        toggleNetworkProtectionPopover()
    }

    private func toggleNetworkProtectionPopover() {
        guard NetworkProtectionKeychainTokenStore().isFeatureActivated else {
            return
        }

        popovers.toggleNetworkProtectionPopover(from: networkProtectionButton, withDelegate: networkProtectionButtonModel)
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

    func listenToVPNToggleNotifications() {
        vpnToggleCancellable = NotificationCenter.default.publisher(for: .ToggleNetworkProtectionInMainWindow).receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard self?.view.window?.isKeyWindow == true else {
                return
            }

            self?.toggleNetworkProtectionPopover()
        }
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
                    self.updateDownloadsButton(source: .pinnedViewsNotification)
                case .homeButton:
                    self.updateHomeButton()
                case .networkProtection:
                    self.networkProtectionButtonModel.updateVisibility()
                case .aiChat:
                    self.updateAIChatButton()
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
                                               selector: #selector(showPasswordsAutoPinnedFeedback(_:)),
                                               name: .passwordsAutoPinned,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showPasswordsPinningOption(_:)),
                                               name: .passwordsPinningPrompt,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showAutoconsentFeedback(_:)),
                                               name: AutoconsentUserScript.newSitePopupHiddenNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(attemptToShowBrokenSitePrompt(_:)),
                                               name: .pageRefreshMonitorDidDetectRefreshPattern,
                                               object: nil)

        UserDefaults.netP
            .publisher(for: \.networkProtectionShouldShowVPNUninstalledMessage)
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] shouldShowUninstalledMessage in
                if shouldShowUninstalledMessage {
                    self?.showVPNUninstalledFeedback()
                    UserDefaults.netP.networkProtectionShouldShowVPNUninstalledMessage = false
                }
            }
            .store(in: &cancellables)
    }

    func listenToFeedbackFormNotifications() {
        feedbackFormCancellable = NotificationCenter.default.publisher(for: .OpenUnifiedFeedbackForm).receive(on: DispatchQueue.main).sink { notification in
            let source = UnifiedFeedbackSource(userInfo: notification.userInfo)
            WindowControllersManager.shared.showShareFeedbackModal(source: source)
        }
    }

    @objc private func showVPNUninstalledFeedback() {
        // Only show the popover if we aren't already presenting one:
        guard view.window?.isKeyWindow == true, (self.presentedViewControllers ?? []).isEmpty else { return }

        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController(message: "DuckDuckGo VPN was uninstalled")
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

    @objc private func showPasswordsAutoPinnedFeedback(_ sender: Notification) {
        DispatchQueue.main.async {
            let popoverMessage = PopoverMessageViewController(message: UserText.passwordManagerAutoPinnedPopoverText)
            popoverMessage.show(onParent: self, relativeTo: self.passwordManagementButton)
        }
    }

    @objc private func showPasswordsPinningOption(_ sender: Notification) {
        guard view.window?.isKeyWindow == true else { return }

        DispatchQueue.main.async {
            self.popovers.showAutofillOnboardingPopover(from: self.passwordManagementButton,
                                                   withDelegate: self) { [weak self] didAddShortcut in
                guard let self = self else { return }
                self.popovers.closeAutofillOnboardingPopover()

                if didAddShortcut {
                    LocalPinningManager.shared.pin(.autofill)
                }
            }
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

    @objc private func attemptToShowBrokenSitePrompt(_ sender: Notification) {
        guard brokenSitePromptLimiter.shouldShowToast(),
              let url = tabCollectionViewModel.selectedTabViewModel?.tab.url, !url.isDuckDuckGo,
              isOnboardingFinished
        else { return }
        showBrokenSitePrompt()
    }

    private var isOnboardingFinished: Bool {
        OnboardingActionsManager.isOnboardingFinished && Application.appDelegate.onboardingStateMachine.state == .onboardingCompleted
    }

    private func showBrokenSitePrompt() {
        guard view.window?.isKeyWindow == true,
              let privacyButton = addressBarViewController?.addressBarButtonsViewController?.privacyEntryPointButton else { return }
        brokenSitePromptLimiter.didShowToast()
        PixelKit.fire(GeneralPixel.siteNotWorkingShown)
        let popoverMessage = PopoverMessageViewController(message: UserText.BrokenSitePrompt.title,
                                                          buttonText: UserText.BrokenSitePrompt.buttonTitle,
                                                          buttonAction: {
            self.brokenSitePromptLimiter.didOpenReport()
            self.addressBarViewController?.addressBarButtonsViewController?.openPrivacyDashboardPopover(entryPoint: .prompt)
            PixelKit.fire(GeneralPixel.siteNotWorkingWebsiteIsBroken)
        },
                                                          shouldShowCloseButton: true,
                                                          autoDismissDuration: nil,
                                                          onDismiss: {
            self.brokenSitePromptLimiter.didDismissToast()
        }
        )
        popoverMessage.show(onParent: self, relativeTo: privacyButton, behavior: .semitransient)
    }

    func toggleDownloadsPopover(keepButtonVisible: Bool) {

        downloadsButton.isHidden = false
        if keepButtonVisible {
            setDownloadButtonHidingTimer()
        }

        popovers.toggleDownloadsPopover(from: downloadsButton, popoverDelegate: self, downloadsDelegate: self)
    }

    func showPasswordManagerPopover(selectedCategory: SecureVaultSorting.Category?, source: PasswordManagementSource) {
        popovers.showPasswordManagementPopover(selectedCategory: selectedCategory, from: passwordManagementButton, withDelegate: self, source: source)
    }

    func showPasswordManagerPopover(selectedWebsiteAccount: SecureVaultModels.WebsiteAccount) {
        popovers.showPasswordManagerPopover(selectedWebsiteAccount: selectedWebsiteAccount, from: passwordManagementButton, withDelegate: self)
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
            case .homePage: 10
            case .popUpWindow: 0
            case .default: 6
            }
        }

        fileprivate var bottomPadding: CGFloat {
            switch self {
            case .homePage: 8
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

        let heightChange: () -> Void
        if animated, let window = view.window, window.isVisible == true {
            heightChange = {
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
            heightChange = {
                performResize()
            }
        }
        if let window = view.window, window.isVisible {
            let dispatchItem = DispatchWorkItem(block: heightChange)
            DispatchQueue.main.async(execute: dispatchItem)
            self.heightChangeAnimation = dispatchItem
        } else {
            // update synchronously for off-screen view
            heightChange()
        }
    }

    private func subscribeToDownloads() {
        // show Downloads button on download completion for downloads started from non-Fire window
        downloadListCoordinator.updates
            .filter { update in
                // filter download completion events only
                !update.item.isBurner && update.isDownloadCompletedUpdate
            }
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self, !self.isDownloadsPopoverShown,
                      DownloadsPreferences.shared.shouldOpenPopupOnCompletion,
                      WindowControllersManager.shared.lastKeyMainWindowController?.window === downloadsButton.window else { return }

                self.popovers.showDownloadsPopoverAndAutoHide(from: downloadsButton, popoverDelegate: self, downloadsDelegate: self)
            }
            .store(in: &downloadsCancellables)

        // update Downloads button visibility and state
        downloadListCoordinator.updates
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] update in
                guard let self, self.view.window?.isVisible == true else { return }
                self.updateDownloadsButton(source: .update(update))
            }
            .store(in: &downloadsCancellables)

        // update Downloads button total progress indicator
        let combinedDownloadProgress = downloadListCoordinator.combinedDownloadProgressCreatingIfNeeded(for: FireWindowSessionRef(window: view.window))
        combinedDownloadProgress.publisher(for: \.totalUnitCount)
            .combineLatest(combinedDownloadProgress.publisher(for: \.completedUnitCount))
            .map { (total, completed) -> Double? in
                guard total > 0, completed < total else { return nil }
                return Double(completed) / Double(total)
            }
            .dropFirst()
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak downloadsProgressView] progress in
                guard let downloadsProgressView else { return }
                if progress == nil, downloadsProgressView.progress != 1 {
                    // show download completed animation before hiding
                    downloadsProgressView.setProgress(1, animated: true)
                }
                downloadsProgressView.setProgress(progress, animated: true)
            }
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

        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.userEditableUrl

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
            passwordManagementButton.isShown = popovers.isPasswordManagementPopoverShown || isAutoFillAutosaveMessageVisible
        }

        popovers.passwordManagementDomain = nil
        guard let url = url, let hostAndPort = url.hostAndPort() else {
            return
        }

        popovers.passwordManagementDomain = hostAndPort
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

    private enum DownloadsButtonUpdateSource {
        case pinnedViewsNotification
        case popoverDidClose
        case update(DownloadListCoordinator.Update)
        case `default`
    }
    private func updateDownloadsButton(source: DownloadsButtonUpdateSource) {
        downloadsButton.menu = NSMenu {
            NSMenuItem(title: LocalPinningManager.shared.shortcutTitle(for: .downloads),
                       action: #selector(toggleDownloadsPanelPinning(_:)),
                       keyEquivalent: "")
        }
        downloadsButton.toolTip = UserText.downloadsShortcutTooltip

        if LocalPinningManager.shared.isPinned(.downloads) {
            downloadsButton.isShown = true
            return
        }

        let fireWindowSession = FireWindowSessionRef(window: view.window)
        let hasActiveDownloads = downloadListCoordinator.hasActiveDownloads(for: fireWindowSession)
        downloadsButton.image = hasActiveDownloads ? .downloadsActive : .downloads

        let hasDownloads = downloadListCoordinator.hasDownloads(for: fireWindowSession)
        if !hasDownloads {
            invalidateDownloadButtonHidingTimer()
        }
        let isTimerActive = downloadsButtonHidingTimer != nil

        downloadsButton.isShown = if popovers.isDownloadsPopoverShown {
            true
        } else if case .popoverDidClose = source, hasDownloads {
            true
        } else if hasDownloads, case .update(let update) = source,
                  update.item.fireWindowSession == fireWindowSession,
                  update.item.added.addingTimeInterval(Constants.downloadsButtonAutoHidingInterval) > Date() {
            true
        } else {
            hasActiveDownloads || isTimerActive
        }

        if downloadsButton.isShown {
            setDownloadButtonHidingTimer()
        }

        // If the user has selected Hide Downloads from the navigation bar context menu, and no downloads are active, then force it to be hidden
        // even if the timer is active.
        if case .pinnedViewsNotification = source {
            if !LocalPinningManager.shared.isPinned(.downloads) {
                invalidateDownloadButtonHidingTimer()
                downloadsButton.isShown = hasActiveDownloads
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
            downloadListCoordinator.hasActiveDownloads(for: FireWindowSessionRef(window: view.window)) ||
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
            Logger.passwordManager.debug("Presenting Save Credentials popover")
            popovers.displaySaveCredentials(credentials,
                                            automaticallySaved: data.automaticallySavedCredentials,
                                            backfilled: data.backfilled,
                                            usingView: passwordManagementButton,
                                            withDelegate: self)
        } else if autofillPreferences.askToSavePaymentMethods, let card = data.creditCard {
            Logger.passwordManager.debug("Presenting Save Payment Method popover")
            popovers.displaySavePaymentMethod(card,
                                              usingView: passwordManagementButton,
                                              withDelegate: self)
        } else if autofillPreferences.askToSaveAddresses, let identity = data.identity {
            Logger.passwordManager.debug("Presenting Save Identity popover")
            popovers.displaySaveIdentity(identity,
                                         usingView: passwordManagementButton,
                                         withDelegate: self)
        } else {
            Logger.passwordManager.error("Received save autofill data call, but there was no data to present")
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

    // MARK: - AI Chat

    private func subscribeToAIChatOnboarding() {
        aiChatMenuConfig.shouldDisplayToolbarOnboardingPopover
            .receive(on: DispatchQueue.main)
            .sink { [weak self]  in
                guard let self = self else { return }
                self.automaticallyShowAIChatOnboardingPopoverIfPossible()
        }.store(in: &cancellables)
    }

    private func automaticallyShowAIChatOnboardingPopoverIfPossible() {
        guard WindowControllersManager.shared.lastKeyMainWindowController?.window === aiChatButton.window else { return }

        popovers.showAIChatOnboardingPopover(from: aiChatButton,
                                             withDelegate: self,
                                             ctaCallback: { [weak self] didAddShortcut in
            guard let self = self else { return }
            self.popovers.closeAIChatOnboardingPopover()

            if didAddShortcut {
                self.showAIChatOnboardingConfirmationPopover()
            }
        })

        aiChatMenuConfig.markToolbarOnboardingPopoverAsShown()
    }

    private func showAIChatOnboardingConfirmationPopover() {
        DispatchQueue.main.async {
            let viewController = PopoverMessageViewController(message: UserText.aiChatOnboardingPopoverConfirmation,
                                                              image: .successCheckmark)
            viewController.show(onParent: self, relativeTo: self.aiChatButton)
        }
    }

    @IBAction func aiChatButtonAction(_ sender: NSButton) {
        AIChatTabOpener.openAIChatTab()
        PixelKit.fire(GeneralPixel.aichatToolbarClicked, includeAppVersionParameter: true)
    }

    private func updateAIChatButton() {
        let menu = NSMenu()
        let title = LocalPinningManager.shared.shortcutTitle(for: .aiChat)
        menu.addItem(withTitle: title, action: #selector(toggleAIChatPanelPinning(_:)), keyEquivalent: "")

        aiChatButton.menu = menu
        aiChatButton.toolTip = UserText.aiChat

        aiChatButton.isHidden = !(LocalPinningManager.shared.isPinned(.aiChat) && aiChatMenuConfig.isFeatureEnabledForToolbarShortcut)
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

        let isPopUpWindow = view.window?.isPopUpWindow ?? false

        if !isPopUpWindow && DefaultVPNFeatureGatekeeper(subscriptionManager: subscriptionManager).isVPNVisible() {
            let networkProtectionTitle = LocalPinningManager.shared.shortcutTitle(for: .networkProtection)
            menu.addItem(withTitle: networkProtectionTitle, action: #selector(toggleNetworkProtectionPanelPinning), keyEquivalent: "")
        }

        if aiChatMenuConfig.isFeatureEnabledForToolbarShortcut {
            let aiChatTitle = LocalPinningManager.shared.shortcutTitle(for: .aiChat)
            menu.addItem(withTitle: aiChatTitle, action: #selector(toggleAIChatPanelPinning), keyEquivalent: "L")
        }
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
    private func toggleAIChatPanelPinning(_ sender: NSMenuItem) {
        LocalPinningManager.shared.togglePinning(for: .aiChat)
    }

    @objc
    private func toggleNetworkProtectionPanelPinning(_ sender: NSMenuItem) {
        LocalPinningManager.shared.togglePinning(for: .networkProtection)
    }

    // MARK: - VPN

    func showNetworkProtectionStatus() {
        popovers.showNetworkProtectionPopover(positionedBelow: networkProtectionButton,
                                              withDelegate: networkProtectionButtonModel)
    }

    /// Sets up the VPN button.
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

        networkProtectionButtonModel.$showVPNButton
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                let isPopUpWindow = self?.view.window?.isPopUpWindow ?? false
                self?.networkProtectionButton.isHidden = isPopUpWindow || !show
            }
            .store(in: &cancellables)

        networkProtectionButtonModel.$buttonImage
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                self?.networkProtectionButton.image = image
            }
            .store(in: &cancellables)
    }

}

extension NavigationBarViewController: OptionsButtonMenuDelegate {

    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu) {
        WindowControllersManager.shared.showDataBrokerProtectionTab()
    }

    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu) {
        BWManager.shared.openBitwarden()
    }

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem) {
        addressBarViewController?
            .addressBarButtonsViewController?
            .openBookmarkPopover(setFavorite: false, accessPoint: .init(sender: sender, default: .moreMenu))
    }

    func optionsButtonMenuRequestedBookmarkAllOpenTabs(_ sender: NSMenuItem) {
        let websitesInfo = tabCollectionViewModel.tabs.compactMap(WebsiteInfo.init)
        BookmarksDialogViewFactory.makeBookmarkAllOpenTabsView(websitesInfo: websitesInfo).show()
    }

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu) {
        popovers.showBookmarkListPopover(from: bookmarkListButton, withDelegate: self, forTab: tabCollectionViewModel.selectedTabViewModel?.tab)
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
        popovers.showPasswordManagementPopover(selectedCategory: selectedCategory, from: passwordManagementButton, withDelegate: self, source: .overflow)
    }

    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu) {
        toggleNetworkProtectionPopover()
    }

    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu) {
        toggleDownloadsPopover(keepButtonVisible: true)
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

    func optionsButtonMenuRequestedAccessibilityPreferences(_ menu: NSMenu) {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .accessibility)
    }

    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu) {
        let url = subscriptionManager.url(for: .purchase)
        WindowControllersManager.shared.showTab(with: .subscription(url))
        PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
    }

    func optionsButtonMenuRequestedSubscriptionPreferences(_ menu: NSMenu) {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .subscription)
    }

    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu) {
        let url = subscriptionManager.url(for: .identityTheftRestoration)
        WindowControllersManager.shared.showTab(with: .identityTheftRestoration(url))
    }
}

// MARK: - NSPopoverDelegate

extension NavigationBarViewController: NSPopoverDelegate {

    /// We check references here because these popovers might be on other windows.
    func popoverDidClose(_ notification: Notification) {
        guard view.window?.isVisible == true else { return }
        if let popover = popovers.downloadsPopover, notification.object as AnyObject? === popover {
            popovers.downloadsPopoverClosed()
            updateDownloadsButton(source: .popoverDidClose)
        } else if let popover = popovers.bookmarkListPopover, notification.object as AnyObject? === popover {
            popovers.bookmarkListPopoverClosed()
            updateBookmarksButton()
        } else if let popover = popovers.saveIdentityPopover, notification.object as AnyObject? === popover {
            popovers.saveIdentityPopoverClosed()
            updatePasswordManagementButton()
        } else if let popover = popovers.saveCredentialsPopover, notification.object as AnyObject? === popover {
            popovers.saveCredentialsPopoverClosed()
            updatePasswordManagementButton()
        } else if let popover = popovers.savePaymentMethodPopover, notification.object as AnyObject? === popover {
            popovers.savePaymentMethodPopoverClosed()
            updatePasswordManagementButton()
        } else if let popover = popovers.aiChatOnboardingPopover, notification.object as AnyObject? === popover {
            popovers.aiChatOnboardingPopoverClosed()
            updateAIChatButton()
        } else if let popover = popovers.autofillOnboardingPopover, notification.object as AnyObject? === popover {
            popovers.autofillOnboardingPopoverClosed()
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

extension NavigationBarViewController: MouseOverButtonDelegate {

    func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        guard sender === bookmarkListButton else { return .none }
        let operation = dragDropManager.validateDrop(info, to: PseudoFolder.bookmarks)
        isMouseOver.pointee = (operation != .none)
        return operation
    }

    func mouseOverButton(_ sender: MouseOverButton, draggingUpdatedWith info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        guard sender === bookmarkListButton else { return .none }
        cursorDraggedOverBookmarkListButton(with: info)

        let operation = dragDropManager.validateDrop(info, to: PseudoFolder.bookmarks)
        isMouseOver.pointee = (operation != .none)
        return operation
    }

    private func cursorDraggedOverBookmarkListButton(with info: any NSDraggingInfo) {
        guard !popovers.bookmarkListPopoverShown else { return }
        let cursorPosition = info.draggingLocation

        // show folder bookmarks menu after 0.3
        if let dragDestination,
           dragDestination.mouseLocation.distance(to: cursorPosition) < Constants.maxDragDistanceToExpandHoveredFolder {

            if Date().timeIntervalSince(dragDestination.hoverStarted) >= Constants.dragOverFolderExpandDelay {
                popovers.showBookmarkListPopover(from: bookmarkListButton, withDelegate: self, forTab: tabCollectionViewModel.selectedTabViewModel?.tab)
            }
        } else {
            self.dragDestination = (mouseLocation: cursorPosition, hoverStarted: Date())
        }
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

        popovers.displaySaveCredentials(mockCredentials,
                                        automaticallySaved: false,
                                        backfilled: false,
                                        usingView: passwordManagementButton,
                                        withDelegate: self)
    }

    fileprivate func showMockCredentialsSavedPopover() {
        let account = SecureVaultModels.WebsiteAccount(title: nil, username: "example-username", domain: "example.com")
        let mockCredentials = SecureVaultModels.WebsiteCredentials(account: account, password: "password".data(using: .utf8)!)

        popovers.displaySaveCredentials(mockCredentials,
                                        automaticallySaved: true,
                                        backfilled: false,
                                        usingView: passwordManagementButton,
                                        withDelegate: self)
    }

}
#endif

extension Notification.Name {
    static let ToggleNetworkProtectionInMainWindow = Notification.Name("com.duckduckgo.vpn.toggle-popover-in-main-window")
    static let OpenUnifiedFeedbackForm = Notification.Name("com.duckduckgo.subscription.open-unified-feedback-form")
}
