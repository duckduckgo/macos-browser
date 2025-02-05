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

protocol TabBarViewModel {
    var titlePublisher: Published<String>.Publisher { get }
    var faviconPublisher: Published<NSImage?>.Publisher { get }
    var tabContentPublisher: AnyPublisher<Tab.TabContent, Never> { get }
    var usedPermissionsPublisher: Published<Permissions>.Publisher { get }
    var audioState: WKWebView.AudioState { get }
    var audioStatePublisher: AnyPublisher<WKWebView.AudioState, Never> { get }
}
extension TabViewModel: TabBarViewModel {
    var titlePublisher: Published<String>.Publisher { $title }
    var faviconPublisher: Published<NSImage?>.Publisher { $favicon }
    var tabContentPublisher: AnyPublisher<Tab.TabContent, Never> { tab.$content.eraseToAnyPublisher() }
    var usedPermissionsPublisher: Published<Permissions>.Publisher { $usedPermissions }
    var audioState: WKWebView.AudioState { tab.audioState }
    var audioStatePublisher: AnyPublisher<WKWebView.AudioState, Never> { tab.audioStatePublisher }
}

protocol TabBarViewItemDelegate: AnyObject {

    @MainActor func tabBarViewItem(_: TabBarViewItem, isMouseOver: Bool)

    @MainActor func tabBarViewItemCanBeDuplicated(_: TabBarViewItem) -> Bool
    @MainActor func tabBarViewItemCanBePinned(_: TabBarViewItem) -> Bool
    @MainActor func tabBarViewItemCanBeBookmarked(_: TabBarViewItem) -> Bool
    @MainActor func tabBarViewItemIsAlreadyBookmarked(_: TabBarViewItem) -> Bool
    @MainActor func tabBarViewAllItemsCanBeBookmarked(_: TabBarViewItem) -> Bool

    @MainActor func tabBarViewItemCloseAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemTogglePermissionAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemCloseOtherAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemCloseToTheLeftAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemCloseToTheRightAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemDuplicateAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemPinAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemBookmarkThisPageAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemRemoveBookmarkAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemBookmarkAllOpenTabsAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemMoveToNewWindowAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemMoveToNewBurnerWindowAction(_: TabBarViewItem)
    @MainActor func tabBarViewItemFireproofSite(_: TabBarViewItem)
    @MainActor func tabBarViewItemMuteUnmuteSite(_: TabBarViewItem)
    @MainActor func tabBarViewItemRemoveFireproofing(_: TabBarViewItem)
    @MainActor func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, replaceContentWithDroppedStringValue: String)

    @MainActor func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState

}
final class TabBarItemCellView: NSView {

    enum WidthStage {
        case full
        case withoutCloseButton
        case withoutTitle

        var isTitleHidden: Bool { self == .withoutTitle }
        var isCloseButtonHidden: Bool { self != .full }
        var isFaviconCentered: Bool { !isTitleHidden }

        init(width: CGFloat) {
            switch width {
            case 0..<61: self = .withoutTitle
            case 61..<120: self = .withoutCloseButton
            default: self = .full
            }
        }
    }

    var widthStage: WidthStage = .full {
        didSet {
            if widthStage != oldValue {
                needsLayout = true
            }
        }
    }

    private enum TextFieldMaskGradientSize {
        static let width: CGFloat = 6
        static let trailingSpace: CGFloat = 0
        static let trailingSpaceWithButton: CGFloat = 20
        static let trailingSpaceWithPermissionAndButton: CGFloat = 40
    }

    fileprivate let faviconImageView = {
        let faviconImageView = NSImageView()
        faviconImageView.imageScaling = .scaleProportionallyDown
        faviconImageView.applyFaviconStyle()
        return faviconImageView
    }()

    fileprivate let audioButton = {
        let audioButton = MouseOverButton(title: "", target: nil, action: #selector(TabBarViewItem.audioButtonAction))
        audioButton.bezelStyle = .shadowlessSquare
        audioButton.cornerRadius = 2
        audioButton.normalTintColor = .audioTabIcon
        audioButton.mouseDownColor = .buttonMouseDown
        audioButton.mouseOverColor = .buttonMouseOver
        audioButton.imagePosition = .imageOnly
        audioButton.imageScaling = .scaleNone
        return audioButton
    }()

    fileprivate let titleTextField = {
        let titleTextField = NSTextField()
        titleTextField.wantsLayer = true
        titleTextField.isEditable = false
        titleTextField.alignment = .left
        titleTextField.drawsBackground = false
        titleTextField.isBordered = false
        titleTextField.font = NSFont.systemFont(ofSize: 13)
        titleTextField.textColor = .labelColor
        titleTextField.lineBreakMode = .byClipping
        return titleTextField
    }()

    fileprivate lazy var permissionButton = {
        let permissionButton = MouseOverButton(title: "", target: nil, action: #selector(TabBarViewItem.permissionButtonAction))
        permissionButton.bezelStyle = .shadowlessSquare
        permissionButton.cornerRadius = 2
        permissionButton.normalTintColor = .button
        permissionButton.mouseDownColor = .buttonMouseDown
        permissionButton.mouseOverColor = .buttonMouseOver
        permissionButton.imagePosition = .imageOnly
        permissionButton.imageScaling = .scaleNone
        return permissionButton
    }()

    fileprivate lazy var closeButton = {
        let closeButton = MouseOverButton(image: .close, target: nil, action: #selector(TabBarViewItem.closeButtonAction))
        closeButton.bezelStyle = .shadowlessSquare
        closeButton.cornerRadius = 2
        closeButton.normalTintColor = .button
        closeButton.mouseDownColor = .buttonMouseDown
        closeButton.mouseOverColor = .buttonMouseOver
        closeButton.imagePosition = .imageOnly
        closeButton.imageScaling = .scaleNone
        return closeButton
    }()

    var target: AnyObject? {
        get {
            closeButton.target
        }
        set {
            closeButton.target = newValue
            audioButton.target = newValue
            permissionButton.target = newValue
        }
    }

    fileprivate let mouseOverView = {
        let mouseOverView = MouseOverView()
        mouseOverView.mouseOverColor = .tabMouseOver
        return mouseOverView
    }()

    fileprivate let rightSeparatorView = ColorView(frame: .zero, backgroundColor: .separator)

    fileprivate lazy var borderLayer: CALayer = {
        let layer = CALayer()
        layer.borderWidth = TabShadowConfig.dividerSize
        layer.opacity = TabShadowConfig.alpha
        layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        layer.cornerRadius = 8
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

    private let leftPixelMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    private let rightPixelMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    private let topContentLineMask: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        return layer
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        clipsToBounds = true

        mouseOverView.cornerRadius = 8
        mouseOverView.maskedCorners = [
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        mouseOverView.layer?.addSublayer(borderLayer)

        addSubview(mouseOverView)
        addSubview(faviconImageView)
        addSubview(audioButton)
        addSubview(titleTextField)
        addSubview(permissionButton)
        addSubview(closeButton)
        addSubview(rightSeparatorView)
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarItemCellView: Bad initializer")
    }

    override func layout() {
        super.layout()
        mouseOverView.frame = bounds

        withoutAnimation {
            borderLayer.frame = bounds
            leftPixelMask.frame = CGRect(x: 0, y: 0, width: TabShadowConfig.dividerSize, height: TabShadowConfig.dividerSize)
            rightPixelMask.frame = CGRect(x: borderLayer.bounds.width - TabShadowConfig.dividerSize, y: 0, width: TabShadowConfig.dividerSize, height: TabShadowConfig.dividerSize)
            topContentLineMask.frame = CGRect(x: 0, y: TabShadowConfig.dividerSize, width: borderLayer.bounds.width, height: borderLayer.bounds.height - TabShadowConfig.dividerSize)
        }

        switch widthStage {
        case .full, .withoutCloseButton:
            layoutForNormalMode()
        case .withoutTitle:
            layoutForCompactMode()
        }

        rightSeparatorView.frame = NSRect(x: bounds.maxX.rounded() - 1, y: bounds.midY - 10, width: 1, height: 20)
    }

    private func layoutForNormalMode() {
        var minX: CGFloat = 9
        if faviconImageView.isShown {
            faviconImageView.frame = NSRect(x: minX, y: bounds.midY - 8, width: 16, height: 16)
            minX = faviconImageView.frame.maxX + 4
        }
        if audioButton.isShown {
            audioButton.frame = NSRect(x: minX, y: bounds.midY - 8, width: 16, height: 16)
            minX = audioButton.frame.maxX
        }
        var maxX = bounds.maxX - 9
        if closeButton.isShown {
            closeButton.frame = NSRect(x: maxX - 16, y: bounds.midY - 8, width: 16, height: 16)
            maxX = closeButton.frame.minX - 4
        } else {
            maxX = max(maxX - 1 /* 28 title offset with favicon */, 12 /* without favicon */)
        }
        if permissionButton.isShown {
            permissionButton.frame = NSRect(x: maxX - 20, y: bounds.midY - 12, width: 24, height: 24)
        }

        titleTextField.frame = NSRect(x: minX, y: bounds.midY - 8, width: bounds.maxX - minX - 8, height: 16)
        updateTitleTextFieldMask()
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

    private func layoutForCompactMode() {
        let numberOfElements: CGFloat = (faviconImageView.isShown ? 1 : 0) + (audioButton.isShown ? 1 : 0) + (permissionButton.isShown ? 1 : 0) + (closeButton.isShown ? 1 : 0) + (titleTextField.isShown ? 1 : 0)
        let elementWidth: CGFloat = 16
        var totalWidth = numberOfElements * elementWidth
        // tighten elements to fit all
        let spacing = min(4, bounds.width - 4 - totalWidth)
        totalWidth += (numberOfElements - 1) * spacing
        // shift all shown elements from center
        var x = (bounds.width - totalWidth) / 2
        if faviconImageView.isShown {
            assert(closeButton.isHidden)
            faviconImageView.frame = NSRect(x: x.rounded(), y: bounds.midY - 8, width: 16, height: 16)
            x = faviconImageView.frame.maxX + spacing
        } else if titleTextField.isShown {
            assert(closeButton.isHidden)
            titleTextField.frame = NSRect(x: 4, y: bounds.midY - 8, width: bounds.maxX - 8, height: 16)
            updateTitleTextFieldMask()
        }
        if audioButton.isShown {
            audioButton.frame = NSRect(x: x.rounded(), y: bounds.midY - 8, width: 16, height: 16)
            x = audioButton.frame.maxX + spacing
        }
        if permissionButton.isShown {
            // make permission button from 16 to 24pt wide depending of available space
            permissionButton.frame = NSRect(x: x.rounded() - spacing.rounded(), y: bounds.midY - 12, width: 16 + spacing.rounded() * 2, height: 24)
            x = permissionButton.frame.maxX
        }
        if closeButton.isShown {
            // close button appears in place of favicon in compact mode
            closeButton.frame = NSRect(x: x.rounded(), y: bounds.midY - 8, width: 16, height: 16)
            x = closeButton.frame.maxX + spacing
        }
    }

    override func updateLayer() {
        NSAppearance.withAppAppearance {
            borderLayer.borderColor = NSColor.tabShadowLine.cgColor
        }
    }

}

@MainActor
final class TabBarViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

    enum Height {
        static let standard: CGFloat = 34
    }
    enum Width {
        static let minimum: CGFloat = 52
        static let minimumSelected: CGFloat = 120
        static let maximum: CGFloat = 240
    }

    private var widthStage: TabBarItemCellView.WidthStage {
        if isSelected || isDragged {
            return .full
        } else {
            return .init(width: view.bounds.size.width)
        }
    }

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

    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: TabBarViewItemDelegate?
    var tabViewModel: TabBarViewModel? {
        guard let representedObject else { return nil }
        guard let tabViewModel = representedObject as? TabBarViewModel else {
            assertionFailure("Unexpected representedObject \(representedObject)")
            return nil
        }
        return tabViewModel
    }

    private(set) var isMouseOver = false

    private var cell: TabBarItemCellView {
        view as! TabBarItemCellView // swiftlint:disable:this force_cast
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarViewItem: Bad initializer")
    }

    override func loadView() {
        view = TabBarItemCellView()

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        cell.target = self
        cell.mouseOverView.delegate = self
        cell.mouseOverView.registerForDraggedTypes([.string])

        updateSubviews()
        setupMenu()
    }

    override func viewWillLayout() {
        cell.widthStage = widthStage
        updateSubviews()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        eventMonitor = nil
    }

    deinit {
        if let eventMonitor {
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

    @objc private func duplicateAction(_ sender: NSButton) {
        delegate?.tabBarViewItemDuplicateAction(self)
    }

    @objc private func pinAction(_ sender: NSButton) {
        delegate?.tabBarViewItemPinAction(self)
    }

    @objc private func fireproofSiteAction(_ sender: NSButton) {
        delegate?.tabBarViewItemFireproofSite(self)
    }

    @objc private func muteUnmuteSiteAction(_ sender: NSButton) {
        delegate?.tabBarViewItemMuteUnmuteSite(self)
    }

    @objc private func removeFireproofingAction(_ sender: NSButton) {
        delegate?.tabBarViewItemRemoveFireproofing(self)
    }

    @objc private func bookmarkThisPageAction(_ sender: Any) {
        delegate?.tabBarViewItemBookmarkThisPageAction(self)
    }

    @objc private func removeFromBookmarksAction(_ sender: Any) {
        delegate?.tabBarViewItemRemoveBookmarkAction(self)
    }

    @objc private func bookmarkAllOpenTabsAction(_ sender: Any) {
        delegate?.tabBarViewItemBookmarkAllOpenTabsAction(self)
    }

    private var lastKnownIndexPath: IndexPath?

    @objc fileprivate func closeButtonAction(_ sender: Any) {
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

    @objc fileprivate func audioButtonAction(_ sender: NSButton) {
        self.delegate?.tabBarViewItemMuteUnmuteSite(self)
    }

    @objc fileprivate func permissionButtonAction(_ sender: NSButton) {
        delegate?.tabBarViewItemTogglePermissionAction(self)
    }

    @objc private func closeOtherAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseOtherAction(self)
    }

    @objc private func closeToTheLeftAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseToTheLeftAction(self)
    }

    @objc private func closeToTheRightAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseToTheRightAction(self)
    }

    @objc private func moveToNewWindowAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemMoveToNewWindowAction(self)
    }

    @objc private func moveToNewBurnerWindowAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemMoveToNewBurnerWindowAction(self)
    }

    func subscribe(to tabViewModel: TabBarViewModel) {
        clearSubscriptions()

        representedObject = tabViewModel
        tabViewModel.titlePublisher.sink { [weak self] title in
            self?.cell.titleTextField.stringValue = title
        }.store(in: &cancellables)

        tabViewModel.faviconPublisher.sink { [weak self] favicon in
            self?.updateFavicon(favicon)
        }.store(in: &cancellables)

        tabViewModel.tabContentPublisher.sink { [weak self] content in
            self?.currentURL = content.userEditableUrl
        }.store(in: &cancellables)

        tabViewModel.usedPermissionsPublisher
            .assign(to: \.usedPermissions, onWeaklyHeld: self)
            .store(in: &cancellables)

        tabViewModel.audioStatePublisher.sink { [weak self] audioState in
            self?.updateAudioPlayState(audioState)
        }.store(in: &cancellables)
    }

    func clear() {
        clearSubscriptions()
        usedPermissions = Permissions()
        cell.faviconImageView.image = nil
        cell.titleTextField.stringValue = ""
    }

    private var isDragged = false {
        didSet {
            updateSubviews()
        }
    }

    private func clearSubscriptions() {
        cancellables.removeAll()
        representedObject = nil
    }

    private func updateSubviews() {
        withoutAnimation {
            if isSelected || isDragged {
                cell.mouseOverView.mouseOverColor = nil
                cell.mouseOverView.backgroundColor = .navigationBarBackground
            } else {
                cell.mouseOverView.mouseOverColor = .tabMouseOver
                cell.mouseOverView.backgroundColor = nil
            }
            cell.borderLayer.isHidden = !isSelected
        }

        let showCloseButton = (isMouseOver && (!widthStage.isCloseButtonHidden || NSApp.isCommandPressed)) || isSelected
        cell.closeButton.isShown = showCloseButton
        cell.faviconImageView.isShown = (cell.faviconImageView.image != nil) && (widthStage != .withoutTitle || !showCloseButton)
        updateSeparatorView()
        cell.titleTextField.isShown = !widthStage.isTitleHidden || (cell.faviconImageView.image == nil && !showCloseButton)

        // Adjust colors for burner window
        if isBurner && cell.faviconImageView.image === TabViewModel.Favicon.burnerHome {
            cell.faviconImageView.contentTintColor = .textColor
        } else {
            cell.faviconImageView.contentTintColor = nil
        }
    }

    private var usedPermissions = Permissions() {
        didSet {
            updateUsedPermissions()
        }
    }
    private func updateUsedPermissions() {
        cell.needsLayout = true
        if usedPermissions.camera.isActive {
            cell.permissionButton.image = .cameraTabActive
        } else if usedPermissions.microphone.isActive {
            cell.permissionButton.image = .microphoneActive
        } else if usedPermissions.camera.isPaused {
            cell.permissionButton.image = .cameraTabBlocked
        } else if usedPermissions.microphone.isPaused {
            cell.permissionButton.image = .microphoneIcon
        } else {
            cell.permissionButton.isHidden = true
            return
        }
        cell.permissionButton.isHidden = false
    }

    private func updateSeparatorView() {
        let newIsHidden = isSelected || isDragged || isLeftToSelected
        if cell.rightSeparatorView.isHidden != newIsHidden {
            cell.rightSeparatorView.isHidden = newIsHidden
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        view.menu = menu
    }

    private func updateFavicon(_ favicon: NSImage?) {
        cell.needsLayout = true
        cell.faviconImageView.isHidden = (favicon == nil)
        cell.faviconImageView.image = favicon
    }

    private func updateAudioPlayState(_ audioState: WKWebView.AudioState) {
        cell.needsLayout = true
        switch audioState {
        case .unmuted(isPlayingAudio: false),
             .muted(isPlayingAudio: false):
            cell.audioButton.isHidden = true

        case .muted(isPlayingAudio: true):
            cell.audioButton.image = .audioMute
            cell.audioButton.isHidden = false

        case .unmuted(isPlayingAudio: true):
            cell.audioButton.image = .audio
            cell.audioButton.isHidden = false
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
        // Duplicate, Pin, Mute Section
        addDuplicateMenuItem(to: menu)
        if !isBurner {
            addPinMenuItem(to: menu)
        }
        addMuteUnmuteMenuItem(to: menu)
        menu.addItem(.separator())

        // Bookmark/Fireproof Section
        addFireproofMenuItem(to: menu)
        if let delegate, delegate.tabBarViewItemIsAlreadyBookmarked(self) {
            removeBookmarkMenuItem(to: menu)
        } else {
            addBookmarkMenuItem(to: menu)
        }
        menu.addItem(.separator())

        // Bookmark All Section
        addBookmarkAllTabsMenuItem(to: menu)
        menu.addItem(.separator())

        // Close Section
        addCloseMenuItem(to: menu)
        addCloseOtherSubmenu(to: menu, tabBarItemState: otherItemsState)
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

    private func removeBookmarkMenuItem(to menu: NSMenu) {
        let bookmarkMenuItem = NSMenuItem(title: UserText.deleteBookmark, action: #selector(removeFromBookmarksAction(_:)), keyEquivalent: "")
        bookmarkMenuItem.target = self
        menu.addItem(bookmarkMenuItem)
    }

    private func addBookmarkAllTabsMenuItem(to menu: NSMenu) {
        let bookmarkMenuItem = NSMenuItem(title: UserText.bookmarkAllTabs, action: #selector(bookmarkAllOpenTabsAction(_:)), keyEquivalent: "")
        bookmarkMenuItem.target = self
        bookmarkMenuItem.isEnabled = delegate?.tabBarViewAllItemsCanBeBookmarked(self) ?? false
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
        guard let audioState = tabViewModel?.audioState else { return }

        let menuItemTitle = audioState.isMuted ? UserText.unmuteTab : UserText.muteTab
        let muteUnmuteMenuItem = NSMenuItem(title: menuItemTitle, action: #selector(muteUnmuteSiteAction(_:)), keyEquivalent: "")
        muteUnmuteMenuItem.target = self
        menu.addItem(muteUnmuteMenuItem)
    }

    private func addCloseMenuItem(to menu: NSMenu) {
        let closeMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        closeMenuItem.target = self
        menu.addItem(closeMenuItem)
    }

    private func addCloseOtherSubmenu(to menu: NSMenu, tabBarItemState: OtherTabBarViewItemsState) {
        let closeOtherMenuItem = NSMenuItem(title: UserText.closeOtherTabs)
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        addCloseTabsToTheLeftMenuItem(to: submenu, areThereTabsToTheLeft: tabBarItemState.hasItemsToTheLeft)
        addCloseTabsToTheRightMenuItem(to: submenu, areThereTabsToTheRight: tabBarItemState.hasItemsToTheRight)
        addCloseOtherMenuItem(to: submenu, areThereOtherTabs: tabBarItemState.hasItemsToTheLeft || tabBarItemState.hasItemsToTheRight)

        closeOtherMenuItem.submenu = submenu
        menu.addItem(closeOtherMenuItem)
    }

    private func addCloseOtherMenuItem(to menu: NSMenu, areThereOtherTabs: Bool) {
        let closeOtherMenuItem = NSMenuItem(title: UserText.closeAllOtherTabs, action: #selector(closeOtherAction(_:)), keyEquivalent: "")
        closeOtherMenuItem.target = self
        closeOtherMenuItem.isEnabled = areThereOtherTabs
        menu.addItem(closeOtherMenuItem)
    }

    private func addCloseTabsToTheLeftMenuItem(to menu: NSMenu, areThereTabsToTheLeft: Bool) {
        let closeTabsToTheLeftMenuItem = NSMenuItem(title: UserText.closeTabsToTheLeft,
                                                     action: #selector(closeToTheLeftAction(_:)),
                                                     keyEquivalent: "")
        closeTabsToTheLeftMenuItem.target = self
        closeTabsToTheLeftMenuItem.isEnabled = areThereTabsToTheLeft
        menu.addItem(closeTabsToTheLeftMenuItem)
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
        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
        self.isMouseOver = isMouseOver
        view.needsLayout = true
        eventMonitor = isMouseOver ? NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if let self, widthStage.isCloseButtonHidden {
                view.needsLayout = true
            }
            return event
        } : nil

        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
        self.isMouseOver = isMouseOver
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

    func mouseOverView(_ sender: MouseOverView, performDragOperation info: any NSDraggingInfo) -> Bool {
        if let droppedString = info.draggingPasteboard.string(forType: .string) {
            delegate?.tabBarViewItem(self, replaceContentWithDroppedStringValue: droppedString)
            return true
        }
        return false
    }

    func mouseOverView(_ sender: MouseOverView, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        if info.draggingPasteboard.availableType(from: [.string]) != nil {
            return .copy
        }
        return []
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 14.0, *)
#Preview("Normal", traits: .fixedLayout(width: 736, height: 450)) {
    TabBarViewItem.PreviewViewController(sections: [
        [
            .init(width: TabBarViewItem.Width.maximum, title: "", favicon: nil, selected: true),
            .init(width: TabBarViewItem.Width.maximum, title: "about:blank", favicon: nil, selected: false),
            .init(width: TabBarViewItem.Width.maximum, title: "about:blank", favicon: nil, selected: true),
        ],
        [
            .init(width: TabBarViewItem.Width.maximum, title: "DuckDuckGo", favicon: .homeFavicon, selected: false),
            .init(width: TabBarViewItem.Width.maximum, title: "Appearance", favicon: .appearance, selected: true),
            .init(width: TabBarViewItem.Width.maximum, title: "Bookmarks", favicon: .bookmarksFolder, selected: false),
        ],
        [
            .init(width: TabBarViewItem.Width.maximum, title: "Something in the tab title to get shrunk", favicon: .aDark, selected: true),
            .init(width: TabBarViewItem.Width.maximum, title: "Somewhere all we go now to get totally drunk", favicon: nil),
            .init(width: TabBarViewItem.Width.maximum, title: "Long Previewable Title with Permissions", favicon: .h, usedPermissions: [
                .camera: .paused,
            ], audioState: .muted(isPlayingAudio: true)),
        ],
        [
            .init(width: TabBarViewItem.Width.maximum, title: "Something in the tab title to be shrunk", favicon: .aDark, usedPermissions: [
                .camera: .active
            ], audioState: .muted(isPlayingAudio: true), selected: true),
            .init(width: TabBarViewItem.Width.maximum, title: "Test 1", favicon: .homeFavicon, usedPermissions: [
                .camera: .disabled(systemWide: true),
            ], audioState: .muted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.Width.maximum, title: "Test 2", favicon: .homeFavicon, usedPermissions: [
                .camera: .paused,
            ], audioState: .muted(isPlayingAudio: true)),
        ],
        [
            .init(width: TabBarViewItem.mediumWidth, title: "", favicon: nil, selected: true),
            .init(width: TabBarViewItem.mediumWidth, title: "about:blank", favicon: nil, selected: false),
            .init(width: TabBarViewItem.Width.maximum, title: "about:blank", favicon: nil, selected: true),
            .init(width: TabBarViewItem.mediumWidth, title: "", favicon: nil, usedPermissions: [
                .microphone: .active
            ], selected: false),
        ],
        [
            .init(width: TabBarViewItem.mediumWidth, title: "DuckDuckGo", favicon: .homeFavicon, selected: false),
            .init(width: TabBarViewItem.Width.maximum, title: "Appearance", favicon: .appearance, selected: true),
            .init(width: TabBarViewItem.mediumWidth, title: "Bookmarks", favicon: .bookmarksFolder, selected: false),
            .init(width: TabBarViewItem.mediumWidth, title: "Appearance", favicon: .appearance, usedPermissions: [
                .microphone: .active
            ]),
        ],
        [
            .init(width: TabBarViewItem.Width.maximum, title: "Something in the tab title to get shrunk", favicon: .aDark, selected: true),
            .init(width: TabBarViewItem.mediumWidth, title: "Somewhere all we go now to get totally drunk", favicon: nil),
            .init(width: TabBarViewItem.mediumWidth, title: "Long Previewable Title with Permissions", favicon: .b, usedPermissions: [
                .camera: .paused,
            ], audioState: .muted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.mediumWidth, title: "Long Previewable Title with Permissions", favicon: .h, usedPermissions: [
                .camera: .active,
            ]),
        ],
        [
            .init(width: TabBarViewItem.Width.maximum, title: "Something in the tab title to be shrunk", favicon: .aDark, usedPermissions: [
                .camera: .active
            ], audioState: .muted(isPlayingAudio: true), selected: true),
            .init(width: TabBarViewItem.mediumWidth, title: "Test 1", favicon: .homeFavicon, usedPermissions: [
                .camera: .disabled(systemWide: true),
            ], audioState: .unmuted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.mediumWidth, title: "Test 2", favicon: nil, usedPermissions: [
                .microphone: .active,
            ], audioState: .muted(isPlayingAudio: true)),
                  .init(width: TabBarViewItem.mediumWidth, title: "Test 2", favicon: .homeFavicon, audioState: .unmuted(isPlayingAudio: true)),
        ],

        [
            .init(width: TabBarViewItem.Width.minimum, title: "Test 9", favicon: .a, usedPermissions: [
                .microphone: .active,
            ]),
            .init(width: TabBarViewItem.Width.maximum, title: "Test 10", favicon: .error, usedPermissions: [
                .camera: .paused,
            ], audioState: .unmuted(isPlayingAudio: true), selected: true),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 11", favicon: .b, usedPermissions: [
                .camera: .active,
            ], audioState: .unmuted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 12", favicon: .c, usedPermissions: [
                .microphone: .active,
            ], audioState: .muted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 13", favicon: .d),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 14", favicon: .e, usedPermissions: [
                .camera: .paused,
            ], audioState: .unmuted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 16", favicon: nil, usedPermissions: [
                .microphone: .active,
            ], audioState: .muted(isPlayingAudio: true)),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 17", favicon: nil),
            .init(width: TabBarViewItem.Width.minimum, title: "Test 18", favicon: nil, usedPermissions: [
                .camera: .paused,
            ], audioState: .unmuted(isPlayingAudio: true)),
                  .init(width: TabBarViewItem.Width.minimum, title: "Test 19", favicon: nil, audioState: .muted(isPlayingAudio: true)),

        ]
    ])._preview_hidingWindowControlsOnAppear()
}

extension TabBarViewItem {
    static let mediumWidth = (TabBarViewItem.Width.maximum + TabBarViewItem.Width.minimum) / 2
    @MainActor
    final class PreviewViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout, TabBarViewItemDelegate {

        final class TabBarViewModelMock: TabBarViewModel {
            var width: CGFloat
            var isSelected: Bool
            @Published var title: String = ""
            var titlePublisher: Published<String>.Publisher { $title }
            @Published var favicon: NSImage?
            var faviconPublisher: Published<NSImage?>.Publisher { $favicon }
            @Published var tabContent: Tab.TabContent = .none
            var tabContentPublisher: AnyPublisher<Tab.TabContent, Never> { $tabContent.eraseToAnyPublisher() }
            @Published var usedPermissions = Permissions()
            var usedPermissionsPublisher: Published<Permissions>.Publisher { $usedPermissions }
            @Published var audioState: WKWebView.AudioState
            var audioStatePublisher: AnyPublisher<WKWebView.AudioState, Never> {
                $audioState.eraseToAnyPublisher()
            }
            init(width: CGFloat, title: String = "Test Title", favicon: NSImage? = .aDark, tabContent: Tab.TabContent = .none, usedPermissions: Permissions = Permissions(), audioState: WKWebView.AudioState? = nil, selected: Bool = false) {
                self.width = width
                self.title = title
                self.favicon = favicon
                self.tabContent = tabContent
                self.usedPermissions = usedPermissions
                self.audioState = audioState ?? .unmuted(isPlayingAudio: false)
                self.isSelected = selected
            }
        }

        let sections: [[TabBarViewModelMock]]
        var collectionViews = [NSCollectionView]()

        init(sections: [[TabBarViewModelMock]]) {
            self.sections = sections
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            view = NSView()
            view.translatesAutoresizingMaskIntoConstraints = false

            var constraints = [NSLayoutConstraint]()
            for (section, items) in sections.enumerated() {
                let collectionView = NSCollectionView()
                collectionViews.append(collectionView)
                collectionView.translatesAutoresizingMaskIntoConstraints = false
                collectionView.dataSource = self
                collectionView.delegate = self
                let layout = NSCollectionViewFlowLayout()
                layout.minimumInteritemSpacing = 0
                layout.minimumLineSpacing = 0
                layout.scrollDirection = .horizontal
                collectionView.collectionViewLayout = layout
                collectionView.backgroundColors = [.clear]

                let selectedItems = items.indices.filter {
                    items[$0].isSelected
                }.map { IndexPath(item: $0, section: 0) }

                view.addSubview(collectionView)
                collectionView.selectItems(at: Set(selectedItems), scrollPosition: .top)

                constraints.append(contentsOf: [
                    collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                    collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                    collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8 + CGFloat(section) * 48),
                    collectionView.heightAnchor.constraint(equalToConstant: 38),
                ])

                let separator = ColorView(frame: .zero, backgroundColor: .navigationBarBackground, borderColor: .separator, borderWidth: 1)
                view.addSubview(separator)
                constraints.append(contentsOf: [
                    separator.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 34),
                    separator.heightAnchor.constraint(equalToConstant: 5),
                    separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ])
            }
            NSLayoutConstraint.activate(constraints)
        }

        func numberOfSections(in _: NSCollectionView) -> Int { 1 }

        func collectionView(_ cv: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            let section = collectionViews.firstIndex(where: { $0 === cv })!
            return sections[section].count
        }

        func collectionView(_ cv: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let section = collectionViews.firstIndex(where: { $0 === cv })!
            let item = TabBarViewItem()
            item.subscribe(to: sections[section][indexPath.item])
            item.isSelected = cv.selectionIndexPaths.contains(indexPath)
            item.isLeftToSelected = cv.selectionIndexPaths.contains(IndexPath(item: indexPath.item + 1, section: 0))
            item.view.toolTip = sections[section][indexPath.item].title
            item.delegate = self
            return item
        }

        func collectionView(_ cv: NSCollectionView, layout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            let section = collectionViews.firstIndex(where: { $0 === cv })!
            let item = sections[section][indexPath.item]
            return NSSize(width: item.width, height: TabBarViewItem.Height.standard)
        }

        func tabBarViewItem(_: TabBarViewItem, isMouseOver: Bool) {}
        func tabBarViewItemCanBeDuplicated(_: TabBarViewItem) -> Bool { false }
        func tabBarViewItemCanBePinned(_: TabBarViewItem) -> Bool { false }
        func tabBarViewItemCanBeBookmarked(_: TabBarViewItem) -> Bool { false }
        func tabBarViewItemIsAlreadyBookmarked(_: TabBarViewItem) -> Bool { false }
        func tabBarViewAllItemsCanBeBookmarked(_: TabBarViewItem) -> Bool { false }
        func tabBarViewItemCloseAction(_: TabBarViewItem) {}
        func tabBarViewItemTogglePermissionAction(_ item: TabBarViewItem) {
            // swiftlint:disable:next force_cast
            let item = item.representedObject as! TabBarViewModelMock
            for (key, value) in item.usedPermissions {
                switch value {
                case .disabled(systemWide: false): item.usedPermissions[key] = .disabled(systemWide: true)
                case .disabled(systemWide: true): item.usedPermissions[key] = .requested(.init(.init(url: nil, domain: "", permissions: [])) { _ in })
                case .requested: item.usedPermissions[key] = .inactive
                case .inactive: item.usedPermissions[key] = .active
                case .active: item.usedPermissions[key] = .paused
                case .paused: item.usedPermissions[key] = .revoking
                case .revoking: item.usedPermissions[key] = .denied
                case .denied: item.usedPermissions[key] = .revoking
                case .reloading: item.usedPermissions[key] = .denied
                }
            }
        }
        func tabBarViewItemCloseOtherAction(_: TabBarViewItem) {}
        func tabBarViewItemCloseToTheLeftAction(_: TabBarViewItem) {}
        func tabBarViewItemCloseToTheRightAction(_: TabBarViewItem) {}
        func tabBarViewItemDuplicateAction(_: TabBarViewItem) {}
        func tabBarViewItemPinAction(_: TabBarViewItem) {}
        func tabBarViewItemBookmarkThisPageAction(_: TabBarViewItem) {}
        func tabBarViewItemRemoveBookmarkAction(_: TabBarViewItem) {}
        func tabBarViewItemBookmarkAllOpenTabsAction(_: TabBarViewItem) {}
        func tabBarViewItemMoveToNewWindowAction(_: TabBarViewItem) {}
        func tabBarViewItemMoveToNewBurnerWindowAction(_: TabBarViewItem) {}
        func tabBarViewItemFireproofSite(_: TabBarViewItem) {}
        func tabBarViewItemMuteUnmuteSite(_ item: TabBarViewItem) {
            // swiftlint:disable:next force_cast
            let item = item.representedObject as! TabBarViewModelMock
            switch item.audioState {
            case .unmuted(isPlayingAudio: false):
                item.audioState = .unmuted(isPlayingAudio: true)
            case .unmuted(isPlayingAudio: true):
                item.audioState = .muted(isPlayingAudio: true)
            case .muted(isPlayingAudio: true):
                item.audioState = .muted(isPlayingAudio: false)
            case .muted(isPlayingAudio: false):
                item.audioState = .unmuted(isPlayingAudio: false)
            }
        }
        func tabBarViewItemRemoveFireproofing(_: TabBarViewItem) {}
        func tabBarViewItem(_: TabBarViewItem, replaceContentWithDroppedStringValue: String) {}
        func otherTabBarViewItemsState(for: TabBarViewItem) -> OtherTabBarViewItemsState {
            .init(hasItemsToTheLeft: false, hasItemsToTheRight: false)
        }
    }
}
#endif
