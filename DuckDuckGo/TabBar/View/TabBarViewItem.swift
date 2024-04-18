//
//  TabBarViewItem.swift
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

struct OtherTabBarViewItemsState {

    let hasItemsToTheLeft: Bool
    let hasItemsToTheRight: Bool

}

protocol TabBarViewItemDelegate: AnyObject {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool)

    func tabBarViewItemCanBeDuplicated(_ tabBarViewItem: TabBarViewItem) -> Bool
    func tabBarViewItemCanBePinned(_ tabBarViewItem: TabBarViewItem) -> Bool
    func tabBarViewItemCanBeBookmarked(_ tabBarViewItem: TabBarViewItem) -> Bool

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemPinAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewBurnerWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMuteUnmuteSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemAudioState(_ tabBarViewItem: TabBarViewItem) -> WKWebView.AudioState?

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState

}

final class TabBarViewItem: NSCollectionViewItem {

    enum Constants {
        static let textFieldPadding: CGFloat = 28
        static let textFieldPaddingNoFavicon: CGFloat = 12
    }

    var widthStage: WidthStage {
        if isSelected || isDragged {
            return .full
        } else {
            return WidthStage(width: view.bounds.size.width)
        }
    }

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

    private var eventMonitor: Any? {
        didSet {
            if let oldValue = oldValue {
                NSEvent.removeMonitor(oldValue)
            }
        }
    }

    var isLeftToSelected: Bool = false {
        didSet {
            updateSeparatorView()
        }
    }

    var isBurner: Bool = false {
        didSet {
            updateSubviews()
        }
    }

    @IBOutlet weak var faviconImageView: NSImageView! {
        didSet {
            faviconImageView.applyFaviconStyle()
        }
    }
    @IBOutlet weak var permissionButton: NSButton!

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var titleTextFieldLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTextFieldLeadingMuteConstraint: NSLayoutConstraint!
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var mouseOverView: MouseOverView!
    @IBOutlet weak var faviconWrapperView: NSView!
    @IBOutlet weak var faviconWrapperViewCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var faviconWrapperViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var permissionCloseButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var tabLoadingPermissionLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var closeButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var mutedTabIcon: NSImageView!
    private let titleTextFieldMaskLayer = CAGradientLayer()

    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: TabBarViewItemDelegate?

    var isMouseOver = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        updateSubviews()
        setupMenu()
        updateTitleTextFieldMask()
        closeButton.isHidden = true
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateSubviews()
        updateTitleTextFieldMask()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        eventMonitor = nil
    }

    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                isDragged = false
            }
            updateSubviews()
            updateUsedPermissions()
            updateTitleTextFieldMask()
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        isDragged = true
        return super.draggingImageComponents
    }

    override func mouseDown(with event: NSEvent) {
        if let menu = view.menu, NSEvent.isContextClick(event) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return
        }

        super.mouseDown(with: event)
    }

    @objc func duplicateAction(_ sender: NSButton) {
        delegate?.tabBarViewItemDuplicateAction(self)
    }

    @objc func pinAction(_ sender: NSButton) {
        delegate?.tabBarViewItemPinAction(self)
    }

    @objc func fireproofSiteAction(_ sender: NSButton) {
        delegate?.tabBarViewItemFireproofSite(self)
    }

    @objc func muteUnmuteSiteAction(_ sender: NSButton) {
        delegate?.tabBarViewItemMuteUnmuteSite(self)
        setupMuteOrUnmutedIcon()
    }

    @objc func removeFireproofingAction(_ sender: NSButton) {
        delegate?.tabBarViewItemRemoveFireproofing(self)
    }

    @objc func bookmarkThisPageAction(_ sender: Any) {
        delegate?.tabBarViewItemBookmarkThisPageAction(self)
    }

    private var lastKnownIndexPath: IndexPath?

    @IBAction func closeButtonAction(_ sender: Any) {
        // due to async nature of NSCollectionView views removal
        // leaving window._lastLeftHit set to the button will prevent
        // continuous clicks on the Close button
        // this should be removed when the Tab Bar is redone without NSCollectionView
        (sender as? NSButton)?.window?.evilHackToClearLastLeftHitInWindow()

        guard let indexPath = self.collectionView?.indexPath(for: self) else {
            // doubleclick event arrived at point when we're already removed
            // pass the closeButton action to the next TabBarViewItem
            if let indexPath = self.lastKnownIndexPath,
               let nextItem = self.collectionView?.item(at: indexPath) as? Self {
                // and set its lastKnownIndexPath in case clicks continue to arrive
                nextItem.lastKnownIndexPath = indexPath
                delegate?.tabBarViewItemCloseAction(nextItem)
            }
            return
        }

        self.lastKnownIndexPath = indexPath
        delegate?.tabBarViewItemCloseAction(self)
    }

    @IBAction func permissionButtonAction(_ sender: NSButton) {
        delegate?.tabBarViewItemTogglePermissionAction(self)
    }

    @objc func closeOtherAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseOtherAction(self)
    }

    @objc func closeToTheRightAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseToTheRightAction(self)
    }

    @objc func moveToNewWindowAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemMoveToNewWindowAction(self)
    }

    @objc func moveToNewBurnerWindowAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemMoveToNewBurnerWindowAction(self)
    }

    func subscribe(to tabViewModel: TabViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        clearSubscriptions()

        tabViewModel.$title.sink { [weak self] title in
            self?.titleTextField.stringValue = title
        }.store(in: &cancellables)

        tabViewModel.$favicon.sink { [weak self] favicon in
            self?.updateFavicon(favicon)
        }.store(in: &cancellables)

        tabViewModel.tab.$content.sink { [weak self] content in
            self?.currentURL = content.url
        }.store(in: &cancellables)

        tabViewModel.$usedPermissions.assign(to: \.usedPermissions, onWeaklyHeld: self).store(in: &cancellables)
    }

    func clear() {
        clearSubscriptions()
        usedPermissions = Permissions()
        faviconImageView.image = nil
        titleTextField.stringValue = ""
    }

    private var isDragged = false {
        didSet {
            updateSubviews()
        }
    }

    private lazy var borderLayer: CALayer = {
        let layer = CALayer()
        layer.borderWidth = TabShadowConfig.dividerSize
        layer.opacity = TabShadowConfig.alpha
        layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        layer.cornerRadius = 11
        layer.mask = layerMask
        return layer
    }()

    private lazy var layerMask: CALayer = {
        let layer = CALayer()
        layer.addSublayer(leftPixelMask)
        layer.addSublayer(rightPixelMask)
        layer.addSublayer(topContentLineMask)
        return layer
    }()

    private lazy var leftPixelMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    private lazy var rightPixelMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    private lazy var topContentLineMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    override func viewWillLayout() {
        super.viewWillLayout()

        withoutAnimation {
            borderLayer.frame = self.view.bounds
            leftPixelMask.frame = CGRect(x: 0, y: 0, width: TabShadowConfig.dividerSize, height: TabShadowConfig.dividerSize)
            rightPixelMask.frame = CGRect(x: borderLayer.bounds.width - TabShadowConfig.dividerSize, y: 0, width: TabShadowConfig.dividerSize, height: TabShadowConfig.dividerSize)
            topContentLineMask.frame = CGRect(x: 0, y: TabShadowConfig.dividerSize, width: borderLayer.bounds.width, height: borderLayer.bounds.height - TabShadowConfig.dividerSize)
        }
    }

    private func updateBorderLayerColor() {
        NSAppearance.withAppAppearance {
            withoutAnimation {
                borderLayer.borderColor = NSColor.tabShadowLine.cgColor
            }
        }
    }

    private func setupView() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 11
        view.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer?.masksToBounds = true
        view.layer?.addSublayer(borderLayer)
    }

    private func clearSubscriptions() {
        cancellables.removeAll()
    }

    private func updateSubviews() {
        NSAppearance.withAppAppearance {
            let backgroundColor: NSColor = isSelected || isDragged ? .navigationBarBackground : .clear
            view.layer?.backgroundColor = backgroundColor.cgColor
            mouseOverView.mouseOverColor = isSelected || isDragged ? .clear : .tabMouseOver
        }

        let showCloseButton = (isMouseOver && !widthStage.isCloseButtonHidden) || isSelected
        closeButton.isHidden = !showCloseButton
        updateSeparatorView()
        permissionCloseButtonTrailingConstraint.isActive = !closeButton.isHidden
        titleTextField.isHidden = widthStage.isTitleHidden && faviconImageView.image != nil
        setupMuteOrUnmutedIcon()

        if mutedTabIcon.isHidden {
            faviconWrapperViewCenterConstraint.priority = titleTextField.isHidden ? .defaultHigh : .defaultLow
            faviconWrapperViewLeadingConstraint.priority = titleTextField.isHidden ? .defaultLow : .defaultHigh
        } else {
            // When the mute icon is visible and the tab is compressed we need to center both
            faviconWrapperViewCenterConstraint.priority = .defaultLow
            faviconWrapperViewLeadingConstraint.priority = .defaultHigh
        }

        updateBorderLayerColor()

        if isSelected {
            borderLayer.isHidden = false
        } else {
            borderLayer.isHidden = true
        }

        // Adjust colors for burner window
        if isBurner && faviconImageView.image === TabViewModel.Favicon.burnerHome {
            faviconImageView.contentTintColor = .textColor
        } else {
            faviconImageView.contentTintColor = nil
        }
    }

    private var usedPermissions = Permissions() {
        didSet {
            updateUsedPermissions()
            updateTitleTextFieldMask()
        }
    }
    private func updateUsedPermissions() {
        if usedPermissions.camera.isActive {
            permissionButton.image = .cameraTabActive
        } else if usedPermissions.microphone.isActive {
            permissionButton.image = .microphoneActive
        } else if usedPermissions.camera.isPaused {
            permissionButton.image = .cameraTabBlocked
        } else if usedPermissions.microphone.isPaused {
            permissionButton.image = .microphoneIcon
        } else {
            permissionButton.isHidden = true
            tabLoadingPermissionLeadingConstraint.isActive = false
            return
        }
        permissionButton.isHidden = false
        tabLoadingPermissionLeadingConstraint.isActive = true
    }

    private func updateSeparatorView() {
        let newIsHidden = isSelected || isDragged || isLeftToSelected
        if rightSeparatorView.isHidden != newIsHidden {
            rightSeparatorView.isHidden = newIsHidden
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        view.menu = menu
    }

    private func updateTitleTextFieldMask() {
        let gradientPadding: CGFloat
        switch (closeButton.isHidden, permissionButton.isHidden) {
        case (true, true):
            gradientPadding = TextFieldMaskGradientSize.trailingSpace
        case (false, true), (true, false):
            gradientPadding = TextFieldMaskGradientSize.trailingSpaceWithButton
        case (false, false):
            gradientPadding = TextFieldMaskGradientSize.trailingSpaceWithPermissionAndButton
        }
        titleTextField.gradient(width: TextFieldMaskGradientSize.width, trailingPadding: gradientPadding)
    }

    private func updateFavicon(_ favicon: NSImage?) {
        faviconWrapperView.isHidden = favicon == nil
        titleTextFieldLeadingConstraint.constant = faviconWrapperView.isHidden ? Constants.textFieldPaddingNoFavicon : Constants.textFieldPadding
        faviconImageView.image = favicon
        faviconImageView.imageScaling = .scaleProportionallyDown
    }

    private func setupMuteOrUnmutedIcon() {
        setupMutedTabIconVisibility()
        setupMutedTabIconColor()
        setupMutedTabIconPosition()
    }

    private func setupMutedTabIconVisibility() {
        switch delegate?.tabBarViewItemAudioState(self) {
        case .muted:
            mutedTabIcon.isHidden = false
        case .unmuted, .none:
            mutedTabIcon.isHidden = true
        }
    }

    private func setupMutedTabIconColor() {
        mutedTabIcon.image?.isTemplate = true
        mutedTabIcon.contentTintColor = .mutedTabIcon
    }

    private func setupMutedTabIconPosition() {
        if mutedTabIcon.isHidden {
            titleTextFieldLeadingConstraint.priority = .defaultHigh
            titleTextFieldLeadingMuteConstraint.priority = .defaultLow
            titleTextFieldLeadingConstraint.constant = faviconWrapperView.isHidden ? Constants.textFieldPaddingNoFavicon : Constants.textFieldPadding
        } else {
            if titleTextField.isHidden {
                titleTextFieldLeadingMuteConstraint.priority = .defaultLow
                titleTextFieldLeadingConstraint.priority = .defaultLow
            } else {
                titleTextFieldLeadingMuteConstraint.priority = .required
                titleTextFieldLeadingConstraint.priority = .defaultLow
            }
        }
    }
}

extension TabBarViewItem: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Initial setup
        menu.removeAllItems()
        let otherItemsState = delegate?.otherTabBarViewItemsState(for: self) ?? .init(hasItemsToTheLeft: true,
                                                                                      hasItemsToTheRight: true)
        let areThereOtherTabs = otherItemsState.hasItemsToTheLeft || otherItemsState.hasItemsToTheRight

        // Menu Items
        // Section 1
        addDuplicateMenuItem(to: menu)
        addPinMenuItem(to: menu)
        menu.addItem(NSMenuItem.separator())

        // Section 2
        addBookmarkMenuItem(to: menu)
        addFireproofMenuItem(to: menu)

        addMuteUnmuteMenuItem(to: menu)
        menu.addItem(NSMenuItem.separator())

        // Section 3
        addCloseMenuItem(to: menu)
        addCloseOtherMenuItem(to: menu, areThereOtherTabs: areThereOtherTabs)
        addCloseTabsToTheRightMenuItem(to: menu, areThereTabsToTheRight: otherItemsState.hasItemsToTheRight)
        if !isBurner {
            addMoveToNewWindowMenuItem(to: menu, areThereOtherTabs: areThereOtherTabs)
        }
    }

    private func addDuplicateMenuItem(to menu: NSMenu) {
        let duplicateMenuItem = NSMenuItem(title: UserText.duplicateTab, action: #selector(duplicateAction(_:)), keyEquivalent: "")
        duplicateMenuItem.target = self
        duplicateMenuItem.isEnabled = delegate?.tabBarViewItemCanBeDuplicated(self) ?? false
        menu.addItem(duplicateMenuItem)
    }

    private func addPinMenuItem(to menu: NSMenu) {
        let pinMenuItem = NSMenuItem(title: UserText.pinTab, action: #selector(pinAction(_:)), keyEquivalent: "")
        pinMenuItem.target = self
        pinMenuItem.isEnabled = delegate?.tabBarViewItemCanBePinned(self) ?? false
        menu.addItem(pinMenuItem)
    }

    private func addBookmarkMenuItem(to menu: NSMenu) {
        let bookmarkMenuItem = NSMenuItem(title: UserText.bookmarkThisPage, action: #selector(bookmarkThisPageAction(_:)), keyEquivalent: "")
        bookmarkMenuItem.target = self
        bookmarkMenuItem.isEnabled = delegate?.tabBarViewItemCanBeBookmarked(self) ?? false
        menu.addItem(bookmarkMenuItem)
    }

    private func addFireproofMenuItem(to menu: NSMenu) {
        var menuItem = NSMenuItem(title: UserText.fireproofSite, action: #selector(fireproofSiteAction(_:)), keyEquivalent: "")
        menuItem.isEnabled = false

        if let url = currentURL, url.canFireproof {
            if FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "") {
                menuItem = NSMenuItem(title: UserText.removeFireproofing, action: #selector(removeFireproofingAction(_:)), keyEquivalent: "")
            }
            menuItem.isEnabled = true
        }
        menuItem.target = self
        menu.addItem(menuItem)
    }

    private func addMuteUnmuteMenuItem(to menu: NSMenu) {
        guard let audioState = delegate?.tabBarViewItemAudioState(self) else { return }

        menu.addItem(NSMenuItem.separator())
        let menuItemTitle = audioState == .muted ? UserText.unmuteTab : UserText.muteTab
        let muteUnmuteMenuItem = NSMenuItem(title: menuItemTitle, action: #selector(muteUnmuteSiteAction(_:)), keyEquivalent: "")
        muteUnmuteMenuItem.target = self
        menu.addItem(muteUnmuteMenuItem)
    }

    private func addCloseMenuItem(to menu: NSMenu) {
        let closeMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        closeMenuItem.target = self
        menu.addItem(closeMenuItem)
    }

    private func addCloseOtherMenuItem(to menu: NSMenu, areThereOtherTabs: Bool) {
        let closeOtherMenuItem = NSMenuItem(title: UserText.closeOtherTabs, action: #selector(closeOtherAction(_:)), keyEquivalent: "")
        closeOtherMenuItem.target = self
        closeOtherMenuItem.isEnabled = areThereOtherTabs
        menu.addItem(closeOtherMenuItem)
    }

    private func addCloseTabsToTheRightMenuItem(to menu: NSMenu, areThereTabsToTheRight: Bool) {
        let closeTabsToTheRightMenuItem = NSMenuItem(title: UserText.closeTabsToTheRight,
                                                     action: #selector(closeToTheRightAction(_:)),
                                                     keyEquivalent: "")
        closeTabsToTheRightMenuItem.target = self
        closeTabsToTheRightMenuItem.isEnabled = areThereTabsToTheRight
        menu.addItem(closeTabsToTheRightMenuItem)
    }

    private func addMoveToNewWindowMenuItem(to menu: NSMenu, areThereOtherTabs: Bool) {
        let moveToNewWindowMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(moveToNewWindowAction(_:)), keyEquivalent: "")
        moveToNewWindowMenuItem.target = self
        moveToNewWindowMenuItem.isEnabled = areThereOtherTabs
        menu.addItem(moveToNewWindowMenuItem)
    }

}

extension TabBarViewItem: MouseClickViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        if self.isMouseOver != isMouseOver {
            delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
        }
        self.isMouseOver = isMouseOver
        view.needsLayout = true
    }

    func mouseClickView(_ mouseClickView: MouseClickView, otherMouseDownEvent: NSEvent) {
        // close on middle-click
        guard otherMouseDownEvent.buttonNumber == 2 else { return }

        guard let indexPath = self.collectionView?.indexPath(for: self) else {
            // doubleclick event arrived at point when we're already removed
            // pass the closeButton action to the next TabBarViewItem
            if let indexPath = self.lastKnownIndexPath,
               let nextItem = self.collectionView?.item(at: indexPath) as? Self {
                // and set its lastKnownIndexPath in case clicks continue to arrive
                nextItem.lastKnownIndexPath = indexPath
                delegate?.tabBarViewItemCloseAction(nextItem)
            }
            return
        }
        self.lastKnownIndexPath = indexPath
        delegate?.tabBarViewItemCloseAction(self)
    }

}

extension TabBarViewItem {

    enum Height: CGFloat {
        case standard = 34
    }

    enum Width: CGFloat {
        case minimum = 52
        case minimumSelected = 120
        case maximum = 240
    }

    enum WidthStage {
        case full
        case withoutCloseButton
        case withoutTitle

        init(width: CGFloat) {
            switch width {
            case 0..<61: self = .withoutTitle
            case 61..<120: self = .withoutCloseButton
            default: self = .full
            }
        }

        var isTitleHidden: Bool { self == .withoutTitle }
        var isCloseButtonHidden: Bool { self != .full }
        var isFaviconCentered: Bool { !isTitleHidden }
    }

}

private extension TabBarViewItem {
    enum TextFieldMaskGradientSize {
        static let width: CGFloat = 6
        static let trailingSpace: CGFloat = 0
        static let trailingSpaceWithButton: CGFloat = 20
        static let trailingSpaceWithPermissionAndButton: CGFloat = 40
    }
}
