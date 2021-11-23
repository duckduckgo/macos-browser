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
    var trackerAnimationView: AnimationView!
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

    private var tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private var isTextFieldEditorFirstResponder = false
    private var isSearchingMode = false
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
    private var updatePrivacyEntryPointDebounced: Debounce?
    private var updateImageButtonDebounced: Debounce?

    required init?(coder: NSCoder) {
        fatalError("AddressBarButtonsViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)

        self.updatePrivacyEntryPointDebounced = Debounce(delay: 0.2, callback: { [weak self] _ in
            self?.updatePrivacyEntryPoint()
        })

        self.updateImageButtonDebounced = Debounce(delay: 0.2, callback: { [weak self] mode in
            // swiftlint:disable force_cast
            self?.updateImageButton(mode as! AddressBarViewController.Mode)
            // swiftlint:enable force_cast
        })
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
    }

    var mouseEnterExitTrackingArea: NSTrackingArea?

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTrackingAreaForHover()
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
        openPrivacyDashboard()
    }

    private func updateBookmarkButtonVisibility() {
        let showBookmarkButton = clearButton.isHidden && (isMouseOver || bookmarkPopover.isShown)
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
        if query.permissions.contains(.camera)
            || (query.permissions.contains(.microphone) && microphoneButton.isHidden && !cameraButton.isHidden) {
            button = cameraButton
        } else if query.permissions.contains(.microphone) {
            button = microphoneButton
        } else if query.permissions.contains(.geolocation) {
            button = geolocationButton
        } else {
            assertionFailure("Unexpected permissions")
            query.handleDecision(grant: false)
            return
        }
        guard !button.isHidden,
              !permissionButtons.isHidden
        else { return }

        permissionAuthorizationPopover.viewController.query = query
        permissionAuthorizationPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
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

    func updateButtons(mode: AddressBarViewController.Mode,
                       isTextFieldEditorFirstResponder: Bool,
                       textFieldValue: AddressBarTextField.Value) {
        stopAnimationsAfterFocus(oldIsTextFieldEditorFirstResponder: self.isTextFieldEditorFirstResponder,
                                 newIsTextFieldEditorFirstResponder: isTextFieldEditorFirstResponder)

        self.isTextFieldEditorFirstResponder = isTextFieldEditorFirstResponder

        if tabCollectionViewModel.selectedTabViewModel == nil {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        isSearchingMode = mode != .browsing
        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !textFieldValue.isEmpty)
        self.updatePrivacyEntryPointDebounced?.call()
        self.updateImageButtonDebounced?.call(mode)
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

        PermissionContextMenu(permissions: permissions,
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

        PermissionContextMenu(permissions: [.microphone: state],
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

        PermissionContextMenu(permissions: [.geolocation: state],
                              domain: selectedTabViewModel.tab.content.url?.host ?? "",
                              delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    private func setupButtons() {
        bookmarkButton.position = .right
        privacyEntryPointButton.position = .left
        privacyEntryPointButton.contentTintColor = .privacyEnabledColor
        imageButton.applyFaviconStyle()
    }

    private var animationViewCache = [String: AnimationView]()
    private func getAnimationView(for animationName: String) -> AnimationView {
        if let animationView = animationViewCache[animationName] {
            return animationView
        }

        let animation = Animation.named(animationName, animationCache: LottieAnimationCache.shared)
        let animationView = AnimationView(animation: animation, imageProvider: tabCollectionViewModel)
        animationView.identifier = NSUserInterfaceItemIdentifier(rawValue: animationName)
        animationViewCache[animationName] = animationView
        return animationView
    }

    private func setupAnimationViews() {
        func addAndLayoutAnimationView(_ animationName: String) -> AnimationView {

            let animationView: AnimationView
            if AppDelegate.isRunningTests {
                animationView = AnimationView()
            } else {
                // For unknown reason, this caused infinite execution of various unit tests.
                animationView = getAnimationView(for: animationName)
            }
            animationWrapperView.addAndLayout(animationView)
            animationView.isHidden = true
            return animationView
        }

        let isAquaMode = NSApp.effectiveAppearance.name == NSAppearance.Name.aqua

        let trackerAnimationName = isAquaMode ? "trackers" : "dark-trackers"
        if trackerAnimationView?.identifier?.rawValue != trackerAnimationName {
            trackerAnimationView?.removeFromSuperview()
            trackerAnimationView = addAndLayoutAnimationView(trackerAnimationName)
        }

        let shieldAnimationName = isAquaMode ? "shield" : "dark-shield"
        if shieldAnimationView?.identifier?.rawValue != shieldAnimationName {
            shieldAnimationView?.removeFromSuperview()
            shieldAnimationView = addAndLayoutAnimationView(shieldAnimationName)
        }

        let shieldDotAnimationName = isAquaMode ? "shield-dot" : "dark-shield-dot"
        if shieldDotAnimationView?.identifier?.rawValue != shieldDotAnimationName {
            shieldDotAnimationView?.removeFromSuperview()
            shieldDotAnimationView = addAndLayoutAnimationView(shieldDotAnimationName)
        }
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
        permissionButtons.isHidden = isTextFieldEditorFirstResponder || trackerAnimationView.isAnimationPlaying

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            if _permissionAuthorizationPopover?.isShown == true {
                permissionAuthorizationPopover.close()
            }
            return
        }

        geolocationButton.buttonState = selectedTabViewModel.usedPermissions.geolocation
        cameraButton.buttonState = selectedTabViewModel.usedPermissions.camera
            .combined(with: selectedTabViewModel.usedPermissions.microphone)
        microphoneButton.buttonState = selectedTabViewModel.usedPermissions.camera == nil
            ? selectedTabViewModel.usedPermissions.microphone
            : nil

        if let query = selectedTabViewModel.permissionAuthorizationQuery {
            if !permissionAuthorizationPopover.isShown {
                openPermissionAuthorizationPopover(for: query)
            }
        } else if _permissionAuthorizationPopover?.isShown == true {
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

    private func updateImageButton(_ mode: AddressBarViewController.Mode) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        // Image button
        switch mode {
        case .browsing:
            imageButton.image = selectedTabViewModel.favicon
        case .searching(withUrl: true):
            imageButton.image = Self.webImage
        case .searching(withUrl: false):
            imageButton.image = Self.homeFaviconImage
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

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode ||
            isTextFieldEditorFirstResponder ||
            isDuckDuckGoUrl ||
            !isHypertextUrl ||
            selectedTabViewModel.errorViewState.isVisible
        imageButtonWrapper.isHidden = !privacyEntryPointButton.isHidden || trackerAnimationView.isAnimationPlaying
    }

    private func updatePrivacyEntryPointIcon() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        guard !trackerAnimationView.isAnimationPlaying else {
            privacyEntryPointButton.image = nil
            return
        }

        switch selectedTabViewModel.tab.content {
        case .url(let url):
            guard let host = url.host else { break }

            let isNotSecure = url.scheme == "http"

            let majorTrackerThresholdPrevalence = 25.0
            let parentEntity = ContentBlocking.trackerDataManager.trackerData.findEntity(forHost: host)
            let isMajorTrackingNetwork = (parentEntity?.prevalence ?? 0.0) >= majorTrackerThresholdPrevalence
            
            let protectionStore = DomainsProtectionUserDefaultsStore() // FIXME
            let isUnprotected = protectionStore.isHostUnprotected(forDomain: host)

            privacyEntryPointButton.image = isNotSecure || isMajorTrackingNetwork || isUnprotected ? Self.shieldDotImage : Self.shieldImage
        default:
            break
        }
    }

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

        trackerAnimationView.isHidden = false
        trackerAnimationView.reloadImages()
        trackerAnimationView.play { [weak self] _ in
            self?.trackerAnimationView.isHidden = true
            self?.updatePrivacyEntryPointIcon()
            self?.updatePermissionButtons()
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

        stopAnimation(trackerAnimationView)
        stopAnimation(shieldAnimationView)
        stopAnimation(shieldDotAnimationView)
    }

    private func stopAnimationsAfterFocus(oldIsTextFieldEditorFirstResponder: Bool, newIsTextFieldEditorFirstResponder: Bool) {
        if !oldIsTextFieldEditorFirstResponder && newIsTextFieldEditorFirstResponder {
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

extension TabCollectionViewModel: AnimationImageProvider {

    func imageForAsset(asset: ImageAsset) -> CGImage? {
        guard let selectedTabViewModel = self.selectedTabViewModel,
              let trackerInfo = selectedTabViewModel.tab.trackerInfo else {
            return nil
        }

        let images = PrivacyIconViewModel.trackerImages(from: trackerInfo)
        switch asset.name {
        case "img_0.png": return images[safe: 0]
        case "img_1.png": return images[safe: 1]
        case "img_2.png": return images[safe: 2]
        case "img_3.png": return images[safe: 3]
        default: return nil
        }
    }

}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
