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

// swiftlint:disable type_body_length
// swiftlint:disable file_length
final class AddressBarButtonsViewController: NSViewController {

    static let homeFaviconImage = NSImage(named: "HomeFavicon")
    static let webImage = NSImage(named: "Web")
    static let bookmarkImage = NSImage(named: "Bookmark")
    static let bookmarkFilledImage = NSImage(named: "BookmarkFilled")
    static let shieldImage = NSImage(named: "Shield")
    static let shieldDotImage = NSImage(named: "ShieldDot")

    weak var delegate: AddressBarButtonsViewControllerDelegate?

    private lazy var bookmarkPopover: BookmarkPopover = {
        let popover = BookmarkPopover()
        popover.delegate = self
        return popover
    }()
  
    private var _permissionAuthorizationPopover: PermissionAuthorizationPopover?
    private var permissionAuthorizationPopover: PermissionAuthorizationPopover {
        if _permissionAuthorizationPopover == nil {
            _permissionAuthorizationPopover = PermissionAuthorizationPopover()
        }
        return _permissionAuthorizationPopover!
    }

    private var _popupBlockedPopover: PopupBlockedPopover?
    private var popupBlockedPopover: PopupBlockedPopover {
        if _popupBlockedPopover == nil {
            _popupBlockedPopover = PopupBlockedPopover()
        }
        return _popupBlockedPopover!
    }

    private var _privacyDashboardPopover: PrivacyDashboardPopover?
    private var privacyDashboardPopover: PrivacyDashboardPopover {
        if _privacyDashboardPopover == nil {
            _privacyDashboardPopover = PrivacyDashboardPopover()
            _privacyDashboardPopover!.delegate = self
        }
        return _privacyDashboardPopover!
    }
    @IBOutlet weak var privacyDashboardPositioningView: NSView!

    @IBOutlet weak var privacyEntryPointButton: AddressBarButton!
    @IBOutlet weak var bookmarkButton: AddressBarButton!
    @IBOutlet weak var imageButtonWrapper: NSView!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!

    @IBOutlet weak var animationWrapperView: NSView!
    var trackerAnimationView1: AnimationView!
    var trackerAnimationView2: AnimationView!
    var trackerAnimationView3: AnimationView!
    var shieldAnimationView: AnimationView!
    var shieldDotAnimationView: AnimationView!

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
    private var isMouseOver = false

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var urlCancellable: AnyCancellable?
    private var trackerInfoCancellable: AnyCancellable?
    private var bookmarkListCancellable: AnyCancellable?
    private var privacyDashboadPendingUpdatesCancellable: AnyCancellable?
    private var trackersAnimationViewStatusCancellable: AnyCancellable?
    private var effectiveAppearanceCancellable: AnyCancellable?
    private var permissionsCancellables = Set<AnyCancellable>()
    private var trackerAnimationTriggerCancellable: AnyCancellable?

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
        setupButtons()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkList()
        subscribePrivacyDashboardPendingUpdates()
        subscribeToEffectiveAppearance()
        updateBookmarkButtonVisibility()

        cameraButton.sendAction(on: .leftMouseDown)
        microphoneButton.sendAction(on: .leftMouseDown)
        geolocationButton.sendAction(on: .leftMouseDown)
        popupsButton.sendAction(on: .leftMouseDown)
    }

    var mouseEnterExitTrackingArea: NSTrackingArea?

    override func viewDidLayout() {
        super.viewDidLayout()
        if view.window?.isPopUpWindow == false {
            updateTrackingAreaForHover()
        }
    }

    func updateTrackingAreaForHover() {
        if let previous = mouseEnterExitTrackingArea {
            view.removeTrackingArea(previous)
        }
        let trackingArea = NSTrackingArea(rect: view.frame, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: view, userInfo: nil)
        view.addTrackingArea(trackingArea)
        mouseEnterExitTrackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        isMouseOver = true
        updateBookmarkButtonVisibility()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseOver = true
        updateBookmarkButtonVisibility()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseOver = false
        updateBookmarkButtonVisibility()
    }

    @IBAction func bookmarkButtonAction(_ sender: Any) {
        openBookmarkPopover(setFavorite: false, accessPoint: .button)
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        delegate?.addressBarButtonsViewControllerClearButtonClicked(self)
    }
    
    @IBAction func privacyEntryPointButtonAction(_ sender: Any) {
        if _permissionAuthorizationPopover?.isShown == true {
            permissionAuthorizationPopover.close()
        }
        _popupBlockedPopover?.close()
        openPrivacyDashboard()
    }

    private func updateBookmarkButtonVisibility() {
        let hasEmptyAddressBar = tabCollectionViewModel.selectedTabViewModel?.addressBarString.isEmpty ?? true
        let showBookmarkButton = clearButton.isHidden && !hasEmptyAddressBar && (isMouseOver || bookmarkPopover.isShown)

        bookmarkButton.isHidden = !showBookmarkButton
    }

    func openBookmarkPopover(setFavorite: Bool, accessPoint: Pixel.Event.AccessPoint) {
        guard let bookmark = bookmarkForCurrentUrl(setFavorite: setFavorite, accessPoint: accessPoint) else {
            assertionFailure("Failed to get a bookmark for the popover")
            return
        }

        if !bookmarkPopover.isShown {
            bookmarkPopover.viewController.bookmark = bookmark
            bookmarkPopover.show(relativeTo: bookmarkButton.bounds, of: bookmarkButton, preferredEdge: .maxY)
        } else {
            updateBookmarkButtonVisibility()
            bookmarkPopover.close()
        }
    }

    func openPermissionAuthorizationPopover(for query: PermissionAuthorizationQuery) {
        let button: NSButton
        var popover: NSPopover = permissionAuthorizationPopover
        if query.permissions.contains(.camera)
            || (query.permissions.contains(.microphone) && microphoneButton.isHidden && !cameraButton.isHidden) {
            button = cameraButton
        } else if query.permissions.contains(.microphone) {
            button = microphoneButton
        } else if query.permissions.contains(.geolocation) {
            button = geolocationButton
        } else if query.permissions.contains(.popups) {
            guard !query.wasShownOnce else { return }
            button = popupsButton
            popover = popupBlockedPopover
        } else {
            assertionFailure("Unexpected permissions")
            query.handleDecision(grant: false)
            return
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

        // Prevent popover from being closed with Privacy Entry Point Button, while pending updates
        if privacyDashboardPopover.viewController.isPendingUpdates() { return }

        guard !privacyDashboardPopover.isShown else {
            privacyDashboardPopover.close()
            return
        }
        privacyDashboardPopover.viewController.tabViewModel = selectedTabViewModel
        privacyDashboardPopover.show(relativeTo: privacyDashboardPositioningView.bounds, of: privacyDashboardPositioningView, preferredEdge: .maxY)

        privacyEntryPointButton.state = .on
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
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let state = selectedTabViewModel.usedPermissions.camera.combined(with: selectedTabViewModel.usedPermissions.microphone)
        else {
            os_log("%s: Selected tab view model is nil or no camera state", type: .error, className)
            return
        }
        if case .requested(let query) = state {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        var permissions = Permissions()
        permissions[.camera] = selectedTabViewModel.usedPermissions.camera
        permissions[.microphone] = selectedTabViewModel.usedPermissions.microphone

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
            os_log("%s: Selected tab view model is nil or no geolocation state", type: .error, className)
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

    private func setupButtons() {
        if view.window?.isPopUpWindow == true {
            privacyEntryPointButton.position = .free
            cameraButton.position = .free
            geolocationButton.position = .free
            popupsButton.position = .free
            microphoneButton.position = .free
            bookmarkButton.isHidden = true
        } else {
            bookmarkButton.position = .right
            privacyEntryPointButton.position = .left
        }

        privacyEntryPointButton.contentTintColor = .privacyEnabledColor
        imageButton.applyFaviconStyle()
    }

    private var animationViewCache = [String: AnimationView]()
    private func getAnimationView(for animationName: String) -> AnimationView {
        if let animationView = animationViewCache[animationName] {
            return animationView
        }

        let animation = Animation.named(animationName, animationCache: LottieAnimationCache.shared)
        let animationView = AnimationView(animation: animation, imageProvider: self)
        animationView.identifier = NSUserInterfaceItemIdentifier(rawValue: animationName)
        animationViewCache[animationName] = animationView
        return animationView
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
                newAnimationView = getAnimationView(for: animationName)
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

    private func subscribePrivacyDashboardPendingUpdates() {
        privacyDashboadPendingUpdatesCancellable?.cancel()

        privacyDashboadPendingUpdatesCancellable = privacyDashboardPopover.viewController
            .$pendingUpdates.receive(on: DispatchQueue.main).sink { [weak self] _ in
            let isPendingUpdate = self?.privacyDashboardPopover.viewController.isPendingUpdates() ?? false

            // Prevent popover from being closed when clicking away, while pending updates
            if isPendingUpdate {
                self?.privacyDashboardPopover.behavior = .applicationDefined
            } else {
                self?.privacyDashboardPopover.close()
#if DEBUG
                self?.privacyDashboardPopover.behavior = .semitransient
#else
                self?.privacyDashboardPopover.behavior = .transient
#endif
            }
        }
    }

    private func updatePermissionButtons() {
        permissionButtons.isHidden = isTextFieldEditorFirstResponder || isAnyTrackerAnimationPlaying
        defer {
            showOrHidePermissionPopoverIfNeeded()
        }

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        geolocationButton.buttonState = selectedTabViewModel.usedPermissions.geolocation
        cameraButton.buttonState = selectedTabViewModel.usedPermissions.camera
            .combined(with: selectedTabViewModel.usedPermissions.microphone)
        microphoneButton.buttonState = selectedTabViewModel.usedPermissions.camera == nil
            ? selectedTabViewModel.usedPermissions.microphone
            : nil
        popupsButton.buttonState = selectedTabViewModel.usedPermissions.popups

        showOrHidePermissionPopoverIfNeeded()
    }

    private func showOrHidePermissionPopoverIfNeeded() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        for permission in PermissionType.allCases {
            guard case .requested(let query) = selectedTabViewModel.usedPermissions[permission] else { continue }
            if !permissionAuthorizationPopover.isShown {
                openPermissionAuthorizationPopover(for: query)
            }
            return
        }
        if _permissionAuthorizationPopover?.isShown == true {
            permissionAuthorizationPopover.close()
        }

    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url,
           isUrlBookmarked || bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkButton.image = Self.bookmarkFilledImage
            bookmarkButton.mouseOverTintColor = NSColor.bookmarkFilledTint
        } else {
            bookmarkButton.mouseOverTintColor = nil
            bookmarkButton.image = Self.bookmarkImage
            bookmarkButton.contentTintColor = nil
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
        imageButtonWrapper.isHidden = !privacyEntryPointButton.isHidden || isAnyTrackerAnimationPlaying
    }

    private func updatePrivacyEntryPointIcon() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        guard !isAnyTrackerAnimationPlaying else {
            privacyEntryPointButton.image = nil
            return
        }

        switch selectedTabViewModel.tab.content {
        case .url(let url):
            guard let host = url.host else { break }

            let isNotSecure = url.scheme == URL.NavigationalScheme.http.rawValue
            let isMajorTrackingNetwork = TrackerRadarManager.shared.isHostMajorTrackingNetwork(host)
            let protectionStore = DomainsProtectionUserDefaultsStore()
            let isUnprotected = protectionStore.isHostUnprotected(forDomain: host)

            privacyEntryPointButton.image = isNotSecure || isMajorTrackingNetwork || isUnprotected ? Self.shieldDotImage : Self.shieldImage
        default:
            break
        }
    }

    // MARK: Tracker Animation

    var lastTrackerImages = [CGImage]()

    private func animateTrackers() {
        guard !privacyEntryPointButton.isHidden,
              let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        switch selectedTabViewModel.tab.content {
        case .url(let url):
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

        if let trackerInfo = selectedTabViewModel.tab.trackerInfo {
            lastTrackerImages = PrivacyIconViewModel.trackerImages(from: trackerInfo)

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
            }
        }

        updatePrivacyEntryPointIcon()
        updatePermissionButtons()
    }

    private func stopAnimations() {
        func stopAnimation(_ animationView: AnimationView) {
            if animationView.isAnimationPlaying || !animationView.isHidden {
                animationView.isHidden = true
                animationView.stop()
            }
        }

        stopAnimation(trackerAnimationView1)
        stopAnimation(trackerAnimationView2)
        stopAnimation(trackerAnimationView3)
        stopAnimation(shieldAnimationView)
        stopAnimation(shieldDotAnimationView)
    }

    private var isAnyTrackerAnimationPlaying: Bool {
        trackerAnimationView1.isAnimationPlaying ||
        trackerAnimationView2.isAnimationPlaying ||
        trackerAnimationView3.isAnimationPlaying
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

        Pixel.fire(.bookmark(isFavorite: setFavorite, fireproofed: .init(url: url), source: accessPoint))

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

}
// swiftlint:enable type_body_length

extension AddressBarButtonsViewController: PermissionContextMenuDelegate {

    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermissions permissions: [PermissionType]) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.set(permissions, muted: true)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermissions permissions: [PermissionType]) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.set(permissions, muted: false)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, revokePermissions permissions: [PermissionType]) {
        for permission in permissions {
            tabCollectionViewModel.selectedTabViewModel?.tab.permissions.revoke(permission)
        }
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, allowPermissionQuery query: PermissionAuthorizationQuery) {
        tabCollectionViewModel.selectedTabViewModel?.tab.permissions.allow(query)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(true, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(false, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, resetStoredPermission permission: PermissionType) {
        PermissionManager.shared.removePermission(forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenuReloadPage(_ menu: PermissionContextMenu) {
        tabCollectionViewModel.selectedTabViewModel?.tab.reload()
    }

}

extension AddressBarButtonsViewController: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        switch notification.object as? NSPopover {

        case bookmarkPopover:
            updateBookmarkButtonVisibility()

        case _privacyDashboardPopover:
            privacyEntryPointButton.state = .off

        default:
            break
        }
    }

}

extension AddressBarButtonsViewController: AnimationImageProvider {

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

// swiftlint:enable type_body_length
// swiftlint:enable file_length
