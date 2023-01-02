//
//  AddressBarButtonsViewController.swift
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
import Combine
import os.log
import Lottie

protocol AddressBarButtonsViewControllerDelegate: AnyObject {

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController)

}

// swiftlint:disable:next type_body_length
final class AddressBarButtonsViewController: NSViewController {

    static let homeFaviconImage = NSImage(named: "Search")
    static let searchImage = NSImage(named: "Search")
    static let webImage = NSImage(named: "Web")
    static let bookmarkImage = NSImage(named: "Bookmark")
    static let bookmarkFilledImage = NSImage(named: "BookmarkFilled")
    static let shieldImage = NSImage(named: "Shield")
    static let shieldDotImage = NSImage(named: "ShieldDot")

    weak var delegate: AddressBarButtonsViewControllerDelegate?

    private var bookmarkPopover: BookmarkPopover?
    private func bookmarkPopoverCreatingIfNeeded() -> BookmarkPopover {
        return bookmarkPopover ?? {
            let popover = BookmarkPopover()
            popover.delegate = self
            self.bookmarkPopover = popover
            return popover
        }()
    }

    private var permissionAuthorizationPopover: PermissionAuthorizationPopover?
    private func permissionAuthorizationPopoverCreatingIfNeeded() -> PermissionAuthorizationPopover {
        return permissionAuthorizationPopover ?? {
            let popover = PermissionAuthorizationPopover()
            self.permissionAuthorizationPopover = popover
            return popover
        }()
    }

    private var popupBlockedPopover: PopupBlockedPopover?
    private func popupBlockedPopoverCreatingIfNeeded() -> PopupBlockedPopover {
        return popupBlockedPopover ?? {
            let popover = PopupBlockedPopover()
            self.popupBlockedPopover = popover
            return popover
        }()
    }

    private var privacyDashboardPopover: PrivacyDashboardPopover?
    private func privacyDashboardPopoverCreatingIfNeeded() -> PrivacyDashboardPopover {
        return privacyDashboardPopover ?? {
            let popover = PrivacyDashboardPopover()
            popover.delegate = self
            self.privacyDashboardPopover = popover
            self.subscribePrivacyDashboardPendingUpdates(privacyDashboardPopover: popover)
            return popover
        }()
    }

    @IBOutlet weak var privacyDashboardPositioningView: NSView!

    @IBOutlet weak var privacyEntryPointButton: MouseOverAnimationButton!
    @IBOutlet weak var bookmarkButton: AddressBarButton!
    @IBOutlet weak var imageButtonWrapper: NSView!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var buttonsContainer: NSStackView!

    @IBOutlet weak var animationWrapperView: NSView!
    var trackerAnimationView1: AnimationView!
    var trackerAnimationView2: AnimationView!
    var trackerAnimationView3: AnimationView!
    var shieldAnimationView: AnimationView!
    var shieldDotAnimationView: AnimationView!
    @IBOutlet weak var notificationAnimationView: NavigationBarBadgeAnimationView!
    
    @IBOutlet weak var permissionButtons: NSView!
    @IBOutlet weak var cameraButton: PermissionButton! {
        didSet {
            cameraButton.isHidden = true
            cameraButton.target = self
            cameraButton.action = #selector(cameraButtonAction(_:))
        }
    }
    @IBOutlet weak var microphoneButton: PermissionButton! {
        didSet {
            microphoneButton.isHidden = true
            microphoneButton.target = self
            microphoneButton.action = #selector(microphoneButtonAction(_:))
        }
    }
    @IBOutlet weak var geolocationButton: PermissionButton! {
        didSet {
            geolocationButton.isHidden = true
            geolocationButton.target = self
            geolocationButton.action = #selector(geolocationButtonAction(_:))
        }
    }
    @IBOutlet weak var popupsButton: PermissionButton! {
        didSet {
            popupsButton.isHidden = true
            popupsButton.target = self
            popupsButton.action = #selector(popupsButtonAction(_:))
        }
    }
    @IBOutlet weak var externalSchemeButton: PermissionButton! {
        didSet {
            externalSchemeButton.isHidden = true
            externalSchemeButton.target = self
            externalSchemeButton.action = #selector(externalSchemeButtonAction(_:))
        }
    }

    @Published private(set) var buttonsWidth: CGFloat = 0

    private var tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    var controllerMode: AddressBarViewController.Mode? {
        didSet {
            updateButtons()
        }
    }
    var isTextFieldEditorFirstResponder = false {
        didSet {
            updateButtons()
        }
    }
    var textFieldValue: AddressBarTextField.Value? {
        didSet {
            updateButtons()
        }
    }
    var isMouseOverNavigationBar = false {
        didSet {
            updateBookmarkButtonVisibility()
        }
    }

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var urlCancellable: AnyCancellable?
    private var trackerInfoCancellable: AnyCancellable?
    private var bookmarkListCancellable: AnyCancellable?
    private var privacyDashboadPendingUpdatesCancellable: AnyCancellable?
    private var trackersAnimationViewStatusCancellable: AnyCancellable?
    private var effectiveAppearanceCancellable: AnyCancellable?
    private var permissionsCancellables = Set<AnyCancellable>()
    private var trackerAnimationTriggerCancellable: AnyCancellable?
    private var isMouseOverAnimationVisibleCancellable: AnyCancellable?
    private var privacyInfoCancellable: AnyCancellable?
    
    private lazy var buttonsBadgeAnimator = NavigationBarBadgeAnimator()
    
    required init?(coder: NSCoder) {
        fatalError("AddressBarButtonsViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAnimationViews()
        setupNotificationAnimationView()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkList()
        subscribeToEffectiveAppearance()
        subscribeToIsMouseOverAnimationVisible()
        updateBookmarkButtonVisibility()
        
        privacyEntryPointButton.toolTip = UserText.privacyDashboardTooltip
    }

    override func viewWillAppear() {
        setupButtons()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    func showBadgeNotification(_ type: NavigationBarBadgeAnimationView.AnimationType) {
        if !isAnyShieldAnimationPlaying {
            buttonsBadgeAnimator.showNotification(withType: type,
                                                  buttonsContainer: buttonsContainer,
                                                  and: notificationAnimationView)
        } else {
            buttonsBadgeAnimator.queuedAnimation = NavigationBarBadgeAnimator.QueueData(selectedTab: tabCollectionViewModel.selectedTab,
                                                                                        animationType: type)
        }
    }
    
    private func playBadgeAnimationIfNecessary() {
        if let queuedNotification = buttonsBadgeAnimator.queuedAnimation {
            // Add small time gap in between animations if badge animation was queued
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if self.tabCollectionViewModel.selectedTab == queuedNotification.selectedTab {
                    self.showBadgeNotification(queuedNotification.animationType)
                } else {
                    self.buttonsBadgeAnimator.queuedAnimation = nil
                }
            }
        }
    }

    var mouseEnterExitTrackingArea: NSTrackingArea?

    override func viewDidLayout() {
        super.viewDidLayout()
        if view.window?.isPopUpWindow == false {
            updateTrackingAreaForHover()
        }
        self.buttonsWidth = buttonsContainer.frame.size.width + 4.0
    }

    func updateTrackingAreaForHover() {
        if let previous = mouseEnterExitTrackingArea {
            view.removeTrackingArea(previous)
        }
        let trackingArea = NSTrackingArea(rect: view.frame, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: view, userInfo: nil)
        view.addTrackingArea(trackingArea)
        mouseEnterExitTrackingArea = trackingArea
    }

    @IBAction func bookmarkButtonAction(_ sender: Any) {
        openBookmarkPopover(setFavorite: false, accessPoint: .button)
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        delegate?.addressBarButtonsViewControllerClearButtonClicked(self)
    }
    
    @IBAction func privacyEntryPointButtonAction(_ sender: Any) {
        if let permissionAuthorizationPopover, permissionAuthorizationPopover.isShown {
            permissionAuthorizationPopover.close()
        }
        popupBlockedPopover?.close()
        openPrivacyDashboard()
    }

    private func updateBookmarkButtonVisibility() {
        guard view.window?.isPopUpWindow == false else { return }

        let hasEmptyAddressBar = tabCollectionViewModel.selectedTabViewModel?.addressBarString.isEmpty ?? true
        let showBookmarkButton = clearButton.isHidden && !hasEmptyAddressBar && (isMouseOverNavigationBar || bookmarkPopover?.isShown == true)

        bookmarkButton.isHidden = !showBookmarkButton
    }

    func openBookmarkPopover(setFavorite: Bool, accessPoint: Pixel.Event.AccessPoint) {
        guard let bookmark = bookmarkForCurrentUrl(setFavorite: setFavorite, accessPoint: accessPoint) else {
            assertionFailure("Failed to get a bookmark for the popover")
            return
        }

        let bookmarkPopover = bookmarkPopoverCreatingIfNeeded()
        if bookmarkPopover.isShown {
            bookmarkButton.isHidden = false
            bookmarkPopover.viewController.bookmark = bookmark
            bookmarkPopover.show(relativeTo: bookmarkButton.bounds, of: bookmarkButton, preferredEdge: .maxY)
        } else {
            updateBookmarkButtonVisibility()
            bookmarkPopover.close()
        }
    }

    func openPermissionAuthorizationPopover(for query: PermissionAuthorizationQuery) {
        let button: NSButton

        lazy var popover: NSPopover = {
            let popover = self.permissionAuthorizationPopoverCreatingIfNeeded()
            popover.behavior = .applicationDefined
            return popover
        }()

        if query.permissions.contains(.camera)
            || (query.permissions.contains(.microphone) && microphoneButton.isHidden && !cameraButton.isHidden) {
            button = cameraButton
        } else {
            assert(query.permissions.count == 1)
            switch query.permissions.first {
            case .microphone:
                button = microphoneButton
            case .geolocation:
                button = geolocationButton
            case .popups:
                guard !query.wasShownOnce else { return }
                button = popupsButton
                popover = popupBlockedPopoverCreatingIfNeeded()
            case .externalScheme:
                guard !query.wasShownOnce else { return }
                button = externalSchemeButton
                popover.behavior = .transient
                query.shouldShowAlwaysAllowCheckbox = true
                query.shouldShowCancelInsteadOfDeny = true
            default:
                assertionFailure("Unexpected permissions")
                query.handleDecision(grant: false)
                return
            }
        }
        guard !button.isHidden,
              !permissionButtons.isHidden
        else { return }

        (popover.contentViewController as? PermissionAuthorizationViewController)?.query = query
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        query.wasShownOnce = true
    }

    func openPrivacyDashboard() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }
        let privacyDashboardPopover = privacyDashboardPopoverCreatingIfNeeded()
        // Prevent popover from being closed with Privacy Entry Point Button, while pending updates
        if privacyDashboardPopover.viewController.isPendingUpdates() { return }

        guard !privacyDashboardPopover.isShown else {
            privacyDashboardPopover.close()
            return
        }
        
        privacyDashboardPopover.viewController.updateTabViewModel(selectedTabViewModel)
        
        let positioningViewInWindow = privacyDashboardPositioningView.convert(privacyDashboardPositioningView.bounds, to: view.window?.contentView)
        privacyDashboardPopover.setPreferredMaxHeight(positioningViewInWindow.origin.y)
        privacyDashboardPopover.show(relativeTo: privacyDashboardPositioningView.bounds, of: privacyDashboardPositioningView, preferredEdge: .maxY)

        privacyEntryPointButton.state = .on
                
        privacyInfoCancellable?.cancel()
        privacyInfoCancellable = selectedTabViewModel.tab.$privacyInfo
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak privacyDashboardPopover, weak selectedTabViewModel] _ in
                guard privacyDashboardPopover?.isShown == true, let tabViewModel = selectedTabViewModel else { return }
                privacyDashboardPopover?.viewController.updateTabViewModel(tabViewModel)
            }
    }

    func updateButtons() {
        stopAnimationsAfterFocus()

        if tabCollectionViewModel.selectedTabViewModel == nil {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !(textFieldValue?.isEmpty ?? true))

        updatePrivacyEntryPoint()
        updateImageButton()
        updatePermissionButtons()
    }

    @IBAction func cameraButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }
        if case .requested(let query) = selectedTabViewModel.usedPermissions.camera {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        var permissions = Permissions()
        permissions.camera = selectedTabViewModel.usedPermissions.camera
        if microphoneButton.isHidden {
            permissions.microphone = selectedTabViewModel.usedPermissions.microphone
        }

        PermissionContextMenu(permissions: permissions.map { ($0, $1) },
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func microphoneButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let state = selectedTabViewModel.usedPermissions.microphone
        else {
            os_log("%s: Selected tab view model is nil or no microphone state", type: .error, className)
            return
        }
        if case .requested(let query) = state {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        PermissionContextMenu(permissions: [(.microphone, state)],
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func geolocationButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let state = selectedTabViewModel.usedPermissions.geolocation
        else {
            os_log("%s: Selected tab view model is nil or no geolocation state", type: .error, className)
            return
        }
        if case .requested(let query) = state {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        PermissionContextMenu(permissions: [(.geolocation, state)],
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func popupsButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let state = selectedTabViewModel.usedPermissions.popups
        else {
            os_log("%s: Selected tab view model is nil or no popups state", type: .error, className)
            return
        }

        let permissions: [(PermissionType, PermissionState)]
        if case .requested = state {
            permissions = selectedTabViewModel.tab.permissions.authorizationQueries.reduce(into: .init()) {
                guard $1.permissions.contains(.popups) else { return }
                $0.append( (.popups, .requested($1)) )
            }
        } else {
            permissions = [(.popups, state)]
        }
        PermissionContextMenu(permissions: permissions,
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func externalSchemeButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let (permissionType, state) = selectedTabViewModel.usedPermissions.first(where: { $0.key.isExternalScheme })
        else {
            os_log("%s: Selected tab view model is nil or no externalScheme state", type: .error, className)
            return
        }

        let permissions: [(PermissionType, PermissionState)]
        if case .requested(let query) = state {
            query.wasShownOnce = false
            openPermissionAuthorizationPopover(for: query)
            return
        }

        permissions = [(permissionType, state)]
        
        PermissionContextMenu(permissions: permissions,
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    private func setupButtons() {
        if view.window?.isPopUpWindow == true {
            privacyEntryPointButton.position = .free            
            cameraButton.position = .free
            geolocationButton.position = .free
            popupsButton.position = .free
            microphoneButton.position = .free
            externalSchemeButton.position = .free
            bookmarkButton.isHidden = true
        } else {
            bookmarkButton.position = .right
            privacyEntryPointButton.position = .left
        }

        privacyEntryPointButton.contentTintColor = .privacyEnabledColor

        imageButton.applyFaviconStyle()
        (imageButton.cell as? NSButtonCell)?.highlightsBy = NSCell.StyleMask(rawValue: 0)

        cameraButton.sendAction(on: .leftMouseDown)
        microphoneButton.sendAction(on: .leftMouseDown)
        geolocationButton.sendAction(on: .leftMouseDown)
        popupsButton.sendAction(on: .leftMouseDown)
        externalSchemeButton.sendAction(on: .leftMouseDown)
    }

    private var animationViewCache = [String: AnimationView]()
    private func getAnimationView(for animationName: String) -> AnimationView? {
        if let animationView = animationViewCache[animationName] {
            return animationView
        }

        guard let animationView = AnimationView(named: animationName,
                                                imageProvider: trackerAnimationImageProvider) else {
            assertionFailure("Missing animation file")
            return nil
        }

        animationViewCache[animationName] = animationView
        return animationView
    }
    
    private func setupNotificationAnimationView() {
        notificationAnimationView.alphaValue = 0.0
    }

    private func setupAnimationViews() {
        func addAndLayoutAnimationViewIfNeeded(animationView: AnimationView?, animationName: String) -> AnimationView {
            if let animationView = animationView, animationView.identifier?.rawValue == animationName {
                return animationView
            }

            animationView?.removeFromSuperview()

            let newAnimationView: AnimationView
            if AppDelegate.isRunningTests {
                newAnimationView = AnimationView()
            } else {
                // For unknown reason, this caused infinite execution of various unit tests.
                newAnimationView = getAnimationView(for: animationName) ?? AnimationView()
            }
            animationWrapperView.addAndLayout(newAnimationView)
            newAnimationView.isHidden = true
            return newAnimationView
        }

        let isAquaMode = NSApp.effectiveAppearance.name == NSAppearance.Name.aqua

        trackerAnimationView1 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView1,
                                                                  animationName: isAquaMode ? "trackers-1" : "dark-trackers-1")
        trackerAnimationView2 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView2,
                                                                  animationName: isAquaMode ? "trackers-2" : "dark-trackers-2")
        trackerAnimationView3 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView3,
                                                                  animationName: isAquaMode ? "trackers-3" : "dark-trackers-3")
        shieldAnimationView = addAndLayoutAnimationViewIfNeeded(animationView: shieldAnimationView,
                                                                animationName: isAquaMode ? "shield" : "dark-shield")
        shieldDotAnimationView = addAndLayoutAnimationViewIfNeeded(animationView: shieldDotAnimationView,
                                                                   animationName: isAquaMode ? "shield-dot" : "dark-shield-dot")
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.stopAnimations()
            self?.subscribeToUrl()
            self?.subscribeToPermissions()
            self?.subscribeToTrackerAnimationTrigger()
            self?.closePopover()
        }
    }

    private func subscribeToUrl() {
        urlCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            updateBookmarkButtonImage()
            return
        }

        urlCancellable = selectedTabViewModel.tab.$content.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.stopAnimations()
            self?.updateBookmarkButtonImage()
        }
    }

    private func subscribeToPermissions() {
        permissionsCancellables = []
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        selectedTabViewModel.$usedPermissions.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updatePermissionButtons()
        }.store(in: &permissionsCancellables)
        selectedTabViewModel.$permissionAuthorizationQuery.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updatePermissionButtons()
        }.store(in: &permissionsCancellables)
    }

    private func subscribeToTrackerAnimationTrigger() {
        trackerAnimationTriggerCancellable?.cancel()

        trackerAnimationTriggerCancellable = tabCollectionViewModel.selectedTabViewModel?.trackersAnimationTriggerPublisher
            .sink { [weak self] _ in
                self?.animateTrackers()
        }
    }

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func subscribePrivacyDashboardPendingUpdates(privacyDashboardPopover: PrivacyDashboardPopover) {
        privacyDashboadPendingUpdatesCancellable?.cancel()
        guard !AppDelegate.isRunningTests else { return }

        privacyDashboadPendingUpdatesCancellable = privacyDashboardPopover.viewController.rulesUpdateObserver
            .$pendingUpdates.dropFirst().receive(on: DispatchQueue.main).sink { [weak privacyDashboardPopover] _ in
            let isPendingUpdate = privacyDashboardPopover?.viewController.isPendingUpdates() ?? false

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

    private func updatePermissionButtons() {
        permissionButtons.isHidden = isTextFieldEditorFirstResponder
            || isAnyTrackerAnimationPlaying
            || (tabCollectionViewModel.selectedTabViewModel?.errorViewState.isVisible ?? true)
        defer {
            showOrHidePermissionPopoverIfNeeded()
        }

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }
        
        if controllerMode == .editing(isUrl: false) {
            [geolocationButton, cameraButton, microphoneButton, popupsButton, externalSchemeButton].forEach {
                $0?.buttonState = .none
            }
        } else {
            geolocationButton.buttonState = selectedTabViewModel.usedPermissions.geolocation

            let (camera, microphone) = PermissionState?.combineCamera(selectedTabViewModel.usedPermissions.camera,
                                                                      withMicrophone: selectedTabViewModel.usedPermissions.microphone)
            cameraButton.buttonState = camera
            microphoneButton.buttonState = microphone

            popupsButton.buttonState = selectedTabViewModel.usedPermissions.popups?.isRequested == true // show only when there're popups blocked
                ? selectedTabViewModel.usedPermissions.popups
                : nil
            externalSchemeButton.buttonState = selectedTabViewModel.usedPermissions.externalScheme
        }
    }

    private func showOrHidePermissionPopoverIfNeeded() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        for permission in selectedTabViewModel.usedPermissions.keys {
            guard case .requested(let query) = selectedTabViewModel.usedPermissions[permission] else { continue }
            let permissionAuthorizationPopover = permissionAuthorizationPopoverCreatingIfNeeded()
            guard !permissionAuthorizationPopover.isShown else {
                if permissionAuthorizationPopover.viewController.query === query { return }
                permissionAuthorizationPopover.close()
                return
            }
            openPermissionAuthorizationPopover(for: query)
            return
        }
        if let permissionAuthorizationPopover, permissionAuthorizationPopover.isShown {
            permissionAuthorizationPopover.close()
        }

    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url,
           isUrlBookmarked || bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkButton.image = Self.bookmarkFilledImage
            bookmarkButton.mouseOverTintColor = NSColor.bookmarkFilledTint
            bookmarkButton.toolTip = UserText.editBookmarkTooltip
        } else {
            bookmarkButton.mouseOverTintColor = nil
            bookmarkButton.image = Self.bookmarkImage
            bookmarkButton.contentTintColor = nil
            bookmarkButton.toolTip = UserText.addBookmarkTooltip
        }
    }

    private func updateImageButton() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        // Image button
        switch controllerMode {
        case .browsing:
            imageButton.image = selectedTabViewModel.favicon
        case .editing(isUrl: true):
            imageButton.image = Self.webImage
        case .editing(isUrl: false):
            imageButton.image = Self.homeFaviconImage
        default:
            imageButton.image = nil
        }

    }

    private func updatePrivacyEntryPoint() {
        self.updatePrivacyEntryPointButton()
        self.updatePrivacyEntryPointIcon()
    }

    private func updatePrivacyEntryPointButton() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        let urlScheme = selectedTabViewModel.tab.content.url?.scheme
        let isHypertextUrl = urlScheme == "http" || urlScheme == "https"
        let isDuckDuckGoUrl = selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch ?? false
        let isEditingMode = controllerMode?.isEditing ?? false
        let isTextFieldValueText = textFieldValue?.isText ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isEditingMode ||
            isTextFieldEditorFirstResponder ||
            isDuckDuckGoUrl ||
            !isHypertextUrl ||
            selectedTabViewModel.errorViewState.isVisible ||
            isTextFieldValueText
        imageButtonWrapper.isHidden = view.window?.isPopUpWindow == true
            || !privacyEntryPointButton.isHidden
            || isAnyTrackerAnimationPlaying
    }

    private func updatePrivacyEntryPointIcon() {
        guard !AppDelegate.isRunningTests else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        guard !isAnyShieldAnimationPlaying else {
            privacyEntryPointButton.image = nil
            return
        }

        switch selectedTabViewModel.tab.content {
        case .url(let url):
            guard let host = url.host else { break }

            let isNotSecure = url.scheme == URL.NavigationalScheme.http.rawValue

            let majorTrackerThresholdPrevalence = 25.0
            let parentEntity = ContentBlocking.shared.trackerDataManager.trackerData.findEntity(forHost: host)
            let isMajorTrackingNetwork = (parentEntity?.prevalence ?? 0.0) >= majorTrackerThresholdPrevalence

            let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
            let isUnprotected = configuration.isUserUnprotected(domain: host)

            let isShieldDotVisible = isNotSecure || isMajorTrackingNetwork || isUnprotected

            privacyEntryPointButton.image = isShieldDotVisible ? Self.shieldDotImage : Self.shieldImage

            let shieldDotMouseOverAnimationNames = MouseOverAnimationButton.AnimationNames(aqua: "shield-dot-mouse-over",
                                                                                           dark: "dark-shield-dot-mouse-over")
            let shieldMouseOverAnimationNames = MouseOverAnimationButton.AnimationNames(aqua: "shield-mouse-over",
                                                                                        dark: "dark-shield-mouse-over")
            privacyEntryPointButton.animationNames = isShieldDotVisible ? shieldDotMouseOverAnimationNames: shieldMouseOverAnimationNames
        default:
            break
        }
    }

    // MARK: Tracker Animation

    let trackerAnimationImageProvider = TrackerAnimationImageProvider()

    private func animateTrackers() {
        guard !privacyEntryPointButton.isHidden,
              let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        switch selectedTabViewModel.tab.content {
        case .url(let url):
            // Don't play the shield animation if mouse is over
            guard !privacyEntryPointButton.isAnimationViewVisible else {
                break
            }

            var animationView: AnimationView
            if url.scheme == "http" {
                animationView = shieldDotAnimationView
            } else {
                animationView = shieldAnimationView
            }

            animationView.isHidden = false
            animationView.play { _ in
                animationView.isHidden = true
            }
        default:
            return
        }

        if let trackerInfo = selectedTabViewModel.tab.privacyInfo?.trackerInfo {
            let lastTrackerImages = PrivacyIconViewModel.trackerImages(from: trackerInfo)
            trackerAnimationImageProvider.lastTrackerImages = lastTrackerImages

            let trackerAnimationView: AnimationView?
            switch lastTrackerImages.count {
            case 0: trackerAnimationView = nil
            case 1: trackerAnimationView = trackerAnimationView1
            case 2: trackerAnimationView = trackerAnimationView2
            default: trackerAnimationView = trackerAnimationView3
            }
            trackerAnimationView?.isHidden = false
            trackerAnimationView?.reloadImages()
            trackerAnimationView?.play { [weak self] _ in
                trackerAnimationView?.isHidden = true
                self?.updatePrivacyEntryPointIcon()
                self?.updatePermissionButtons()
                self?.playBadgeAnimationIfNecessary()
            }
        }

        updatePrivacyEntryPointIcon()
        updatePermissionButtons()
    }

    private func closePopover() {
        privacyDashboardPopover?.close()
    }
    
    private func stopAnimations(trackerAnimations: Bool = true,
                                shieldAnimations: Bool = true,
                                badgeAnimations: Bool = true) {
        func stopAnimation(_ animationView: AnimationView) {
            if animationView.isAnimationPlaying || !animationView.isHidden {
                animationView.isHidden = true
                animationView.stop()
            }
        }

        if trackerAnimations {
            stopAnimation(trackerAnimationView1)
            stopAnimation(trackerAnimationView2)
            stopAnimation(trackerAnimationView3)
        }
        if shieldAnimations {
            stopAnimation(shieldAnimationView)
            stopAnimation(shieldDotAnimationView)
        }
        if badgeAnimations {
            stopNotificationBadgeAnimations()
        }
    }
    
    private func stopNotificationBadgeAnimations() {
        notificationAnimationView.removeAnimation()
        buttonsBadgeAnimator.queuedAnimation = nil
    }

    private var isAnyTrackerAnimationPlaying: Bool {
        trackerAnimationView1.isAnimationPlaying ||
        trackerAnimationView2.isAnimationPlaying ||
        trackerAnimationView3.isAnimationPlaying
    }

    private var isAnyShieldAnimationPlaying: Bool {
        shieldAnimationView.isAnimationPlaying ||
        shieldDotAnimationView.isAnimationPlaying
    }

    private func stopAnimationsAfterFocus() {
        if isTextFieldEditorFirstResponder {
            stopAnimations()
        }
    }

    private func bookmarkForCurrentUrl(setFavorite: Bool, accessPoint: Pixel.Event.AccessPoint) -> Bookmark? {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let url = selectedTabViewModel.tab.content.url else {
            assertionFailure("No URL for bookmarking")
            return nil
        }

        if let bookmark = bookmarkManager.getBookmark(for: url) {
            if setFavorite {
                bookmark.isFavorite = true
                bookmarkManager.update(bookmark: bookmark)
            }

            return bookmark
        }

        let bookmark = bookmarkManager.makeBookmark(for: url,
                                                    title: selectedTabViewModel.title,
                                                    isFavorite: setFavorite)
        updateBookmarkButtonImage(isUrlBookmarked: bookmark != nil)

        return bookmark
    }

    private func subscribeToEffectiveAppearance() {
        effectiveAppearanceCancellable = NSApp.publisher(for: \.effectiveAppearance)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupAnimationViews()
                self?.updatePrivacyEntryPointIcon()
            }
    }

    private func subscribeToIsMouseOverAnimationVisible() {
        isMouseOverAnimationVisibleCancellable = privacyEntryPointButton.$isAnimationViewVisible
            .dropFirst()
            .sink { [weak self] isAnimationViewVisible in
   
                if isAnimationViewVisible {
                    self?.stopAnimations(trackerAnimations: false, shieldAnimations: true, badgeAnimations: false)
                } else {
                    self?.updatePrivacyEntryPointIcon()
                }
            }
    }

}

extension AddressBarButtonsViewController: PermissionContextMenuDelegate {

    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermissions permissions: [PermissionType]) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.set(permissions, muted: true)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermissions permissions: [PermissionType]) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.set(permissions, muted: false)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, allowPermissionQuery query: PermissionAuthorizationQuery) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.allow(query)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.allow, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.deny, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, resetStoredPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.ask, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenuReloadPage(_ menu: PermissionContextMenu) {
        tabCollectionViewModel.selectedTabViewModel?.reload()
    }

}

extension AddressBarButtonsViewController: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        switch notification.object as? NSPopover {
        case bookmarkPopover:
            updateBookmarkButtonVisibility()

        case privacyDashboardPopover:
            privacyEntryPointButton.state = .off

        default:
            break
        }
    }

}

final class TrackerAnimationImageProvider: AnimationImageProvider {

    var lastTrackerImages = [CGImage]()

    func imageForAsset(asset: ImageAsset) -> CGImage? {
        switch asset.name {
        case "img_0.png": return lastTrackerImages[safe: 0]
        case "img_1.png": return lastTrackerImages[safe: 1]
        case "img_2.png": return lastTrackerImages[safe: 2]
        case "img_3.png": return lastTrackerImages[safe: 3]
        default: return nil
        }
    }

}
