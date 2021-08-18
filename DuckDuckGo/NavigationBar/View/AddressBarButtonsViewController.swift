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

protocol AddressBarButtonsViewControllerDelegate: AnyObject {

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController)

}

// swiftlint:disable type_body_length
final class AddressBarButtonsViewController: NSViewController {

    static let homeFaviconImage = NSImage(named: "HomeFavicon")
    static let webImage = NSImage(named: "Web")
    static let bookmarkImage = NSImage(named: "Bookmark")
    static let bookmarkFilledImage = NSImage(named: "BookmarkFilled")

    weak var delegate: AddressBarButtonsViewControllerDelegate?

    private lazy var bookmarkPopover = BookmarkPopover()
  
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

    @IBOutlet weak var privacyEntryPointButton: PrivacyEntryPointAddressBarButton!
    @IBOutlet weak var trackersAnimationView: TrackersAnimationView!
    @IBOutlet weak var bookmarkButton: AddressBarButton!
    @IBOutlet weak var imageButtonWrapper: NSView!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!

    @IBOutlet weak var fireproofedButtonDivider: NSBox! {
        didSet {
            fireproofedButtonDivider.isHidden = true
        }
    }

    @IBOutlet weak var fireproofedButton: NSButton! {
        didSet {
            fireproofedButton.isHidden = true
            fireproofedButton.target = self
            fireproofedButton.action = #selector(fireproofedButtonAction)
        }
    }

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

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var urlCancellable: AnyCancellable?
    private var trackerInfoCancellable: AnyCancellable?
    private var bookmarkListCancellable: AnyCancellable?
    private var trackersAnimationViewStatusCancellable: AnyCancellable?
    private var effectiveAppearanceCancellable: AnyCancellable?
    private var permissionsCancellables = Set<AnyCancellable>()

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

        setupButtons()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkList()
        subscribeToTrackersAnimationViewStatus()
        subscribeToEffectiveAppearance()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showUndoFireproofingPopover(_:)),
                                               name: FireproofDomains.Constants.newFireproofDomainNotification,
                                               object: nil)

        cameraButton.sendAction(on: .leftMouseDown)
        microphoneButton.sendAction(on: .leftMouseDown)
        geolocationButton.sendAction(on: .leftMouseDown)
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

    @objc func fireproofedButtonAction(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel, let button = sender as? NSButton else {
            return
        }

        if let host = selectedTabViewModel.tab.content.url?.host, FireproofDomains.shared.isFireproof(fireproofDomain: host) {
            let viewController = FireproofInfoViewController.create(for: host)
            present(viewController, asPopoverRelativeTo: button.frame, of: button.superview!, preferredEdge: .minY, behavior: .transient)
        }
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
        guard !privacyDashboardPopover.isShown else {
            privacyDashboardPopover.close()
            return
        }
        privacyDashboardPopover.viewController.tabViewModel = selectedTabViewModel
        privacyDashboardPopover.show(relativeTo: privacyEntryPointButton.bounds, of: privacyEntryPointButton, preferredEdge: .maxY)

        privacyEntryPointButton.state = .on
    }

    func updateButtons(mode: AddressBarViewController.Mode,
                       isTextFieldEditorFirstResponder: Bool,
                       textFieldValue: AddressBarTextField.Value) {
        self.isTextFieldEditorFirstResponder = isTextFieldEditorFirstResponder

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        let isSearchingMode = mode != .browsing
        let isURLNil = selectedTabViewModel.tab.content.url == nil
        let isDuckDuckGoUrl = selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode || isTextFieldEditorFirstResponder || isDuckDuckGoUrl || isURLNil
        trackersAnimationView.isHidden = privacyEntryPointButton.isHidden
        imageButtonWrapper.isHidden = !privacyEntryPointButton.isHidden

        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !textFieldValue.isEmpty)
        bookmarkButton.isHidden = !clearButton.isHidden || textFieldValue.isEmpty

        // Image button
        switch mode {
        case .browsing:
            imageButton.image = selectedTabViewModel.favicon
        case .searching(withUrl: true):
            imageButton.image = Self.webImage
        case .searching(withUrl: false):
            imageButton.image = Self.homeFaviconImage
        }

        updatePermissionButtons()
        updateFireproofedButton()
    }

    private func updateFireproofedButton() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        if let url = selectedTabViewModel.tab.content.url,
           url.showFireproofStatus,
           !privacyEntryPointButton.isHidden,
           !trackersAnimationView.isAnimating {
            fireproofedButtonDivider.isHidden = !FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "")
            fireproofedButton.isHidden = !FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "")
        } else {
            fireproofedButtonDivider.isHidden = true
            fireproofedButton.isHidden = true
        }
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

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToUrl()
            self?.subscribeToTrackerInfo()
            self?.subscribeToPermissions()
        }
    }

    private func subscribeToUrl() {
        urlCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            updateBookmarkButtonImage()
            return
        }

        urlCancellable = selectedTabViewModel.tab.$content.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func subscribeToTrackerInfo() {
        trackerInfoCancellable?.cancel()

        updatePrivacyViews(trackerInfo: tabCollectionViewModel.selectedTabViewModel?.tab.trackerInfo, animated: false)
        trackerInfoCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.$trackerInfo
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trackerInfo in
                self?.updatePrivacyViews(trackerInfo: trackerInfo, animated: true)
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

    private func updatePermissionButtons() {
        permissionButtons.isHidden = isTextFieldEditorFirstResponder || trackersAnimationView.isAnimating

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

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url,
           isUrlBookmarked || bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkButton.image = Self.bookmarkFilledImage
            bookmarkButton.contentTintColor = NSColor.bookmarkFilledTint
        } else {
            bookmarkButton.image = Self.bookmarkImage
            bookmarkButton.contentTintColor = nil
        }
    }

    private func updatePrivacyViews(trackerInfo: TrackerInfo?, animated: Bool) {
        guard let trackerInfo = trackerInfo,
              !trackerInfo.trackersBlocked.isEmpty else {
            privacyEntryPointButton.reset()
            trackersAnimationView.reset()
            return
        }

        // Animate only when the first tracker is blocked
        if animated {
            if trackerInfo.trackersBlocked.count == 1 {
                privacyEntryPointButton.animate()
                trackersAnimationView.animate()
            }
        } else {
            privacyEntryPointButton.setFinal()
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

    @objc private func showUndoFireproofingPopover(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
            let domain = sender.userInfo?[FireproofDomains.Constants.newFireproofDomainKey] as? String else { return }

        DispatchQueue.main.async {
            let viewController = UndoFireproofingViewController.create(for: domain)
            let frame = self.fireproofedButton.frame.insetFromLineOfDeath()

            self.present(viewController,
                         asPopoverRelativeTo: frame,
                         of: self.fireproofedButton.superview!,
                         preferredEdge: .minY,
                         behavior: .applicationDefined)
        }
    }

    func subscribeToTrackersAnimationViewStatus() {
        trackersAnimationViewStatusCancellable = trackersAnimationView.$isAnimating
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFireproofedButton()
                self?.updatePermissionButtons()
        }
    }

    private func subscribeToEffectiveAppearance() {
        effectiveAppearanceCancellable = NSApp.publisher(for: \.effectiveAppearance)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let trackerInfo = self?.tabCollectionViewModel.selectedTabViewModel?.tab.trackerInfo else {
                    return
                }
                self?.updatePrivacyViews(trackerInfo: trackerInfo, animated: false)
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
        case _privacyDashboardPopover:
            privacyEntryPointButton.state = .off

        default:
            break
        }
    }

}
