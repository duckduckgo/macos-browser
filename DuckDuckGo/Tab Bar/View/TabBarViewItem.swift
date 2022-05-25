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
import os.log
import Combine
import Carbon.HIToolbox

struct OtherTabBarViewItemsState {

    let hasItemsToTheLeft: Bool
    let hasItemsToTheRight: Bool

}

protocol TabBarViewItemDelegate: AnyObject {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool)

    func tabBarViewItemSelectAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem)

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState

}

// swiftlint:disable type_body_length
final class TabBarViewItem: NSCollectionViewItem {

    enum Constants {
        static let textFieldPadding: CGFloat = 32
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

    private var commandPressedMonitor: Any? {
        didSet {
            if let oldValue = oldValue {
                NSEvent.removeMonitor(oldValue)
            }
        }
    }

    var isSeparatorHidden: Bool = false {
        didSet {
            updateSeparatorView()
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
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var mouseOverView: MouseOverView!
    @IBOutlet weak var mouseClickView: MouseClickView!
    @IBOutlet weak var faviconWrapperView: NSView!
    @IBOutlet weak var faviconWrapperViewCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var faviconWrapperViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var permissionLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var permissionTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var closeButtonTrailingConstraint: NSLayoutConstraint!

    private let titleTextFieldMaskLayer = CAGradientLayer()

    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()
    private var closeButtonFirstResponderObserver: NSKeyValueObservation?

    weak var delegate: TabBarViewItemDelegate?

    private var isMouseOver = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        updateSubviews()
        setupMenu()
        closeButton.isHidden = true
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateSubviews()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.lastKnownIndexPath = self.collectionView?.indexPath(for: self)
        setupCloseButtonFirstResponderObserver()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        commandPressedMonitor = nil
        closeButtonFirstResponderObserver = nil
    }

    deinit {
        if let commandPressedMonitor = commandPressedMonitor {
            NSEvent.removeMonitor(commandPressedMonitor)
        }
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                isDragged = false
            }
            updateUsedPermissions()
            updateSubviews()

            self.view.setAccessibilityValue(isSelected)
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        isDragged = true
        return super.draggingImageComponents
    }

    @objc func duplicateAction(_ sender: NSButton) {
        delegate?.tabBarViewItemDuplicateAction(self)
    }

    @objc func fireproofSiteAction(_ sender: NSButton) {
        delegate?.tabBarViewItemFireproofSite(self)
    }

    @objc func removeFireproofingAction(_ sender: NSButton) {
        delegate?.tabBarViewItemRemoveFireproofing(self)
    }

    @objc func bookmarkThisPageAction(_ sender: Any) {
        delegate?.tabBarViewItemBookmarkThisPageAction(self)
    }

    private var lastKnownIndexPath: IndexPath?

    var indexPath: IndexPath? {
        collectionView?.indexPath(for: self) ?? lastKnownIndexPath
    }

    func scrollIntoView(completionHandler: ((Bool) -> Void)? = nil) {
        guard let indexPath = self.indexPath else { return }
        (self.collectionView as? TabBarCollectionView)?.scroll(to: indexPath.item, completionHandler: completionHandler)
    }

    @IBAction func close(_ sender: Any) {
        guard let indexPath = indexPath else {
            // doubleclick event arrived at point when we're already removed
            // pass the closeButton action to the next TabBarViewItem
            // TODO: Validate it still works // swiftlint:disable:this todo
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

    @objc func performClick(_ sender: Any) {
        delegate?.tabBarViewItemSelectAction(self)
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Space {
            performClick(self)
            return
        }
        super.keyDown(with: event)
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

    override var title: String? {
        didSet {
            titleTextField.stringValue = title ?? ""
            view.setAccessibilityTitle(title)
            view.setAccessibilityLabel(title)
        }
    }

    func subscribe(to tabViewModel: TabViewModel, at indexPath: IndexPath) {
        self.lastKnownIndexPath = indexPath
        clearSubscriptions()

        tabViewModel.$title.map { $0 }.assign(to: \.title, onWeaklyHeld: self).store(in: &cancellables)

        tabViewModel.$favicon.sink { [weak self] favicon in
            self?.updateFavicon(favicon)
        }.store(in: &cancellables)

        tabViewModel.tab.$content.sink { [weak self] content in
            self?.currentURL = content.url
        }.store(in: &cancellables)
        // TODO: Used permissions/url? accessibility // swiftlint:disable:this todo
        tabViewModel.$usedPermissions.assign(to: \.usedPermissions, onWeaklyHeld: self).store(in: &cancellables)
    }

    private func setupCloseButtonFirstResponderObserver() {
        closeButtonFirstResponderObserver = self.closeButton.window?
            .observe(\.firstResponder, options: [.initial, .new, .old]) { [weak self] _, change in
                guard let self = self,
                      change.oldValue ?? nil === self.closeButton || change.newValue ?? nil === self.closeButton
                else { return }

                self.updateSubviews()
        }
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

    private var collectionViewCancellable: AnyCancellable?
    private func setupView() {
        mouseOverView.delegate = self
        mouseClickView.delegate = self

        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer?.masksToBounds = true

        view.setAccessibilityRole(.radioButton)
        view.setAccessibilityRoleDescription("tab")
        view.setAccessibilitySubrole(.tabButtonSubrole)
        view.setAccessibilityValue(false)

        collectionViewCancellable = self.publisher(for: \.collectionView).sink { [weak self] collectionView in
            if let collectionView = collectionView {
                self?.view.setAccessibilityParent(collectionView)
            }
        }
    }

    private func clearSubscriptions() {
        cancellables.removeAll()
    }

    private func updateSubviews() {
        NSAppearance.withAppAppearance {
            let backgroundColor = isSelected || isDragged ? NSColor.interfaceBackgroundColor : NSColor.clear
            view.layer?.backgroundColor = backgroundColor.cgColor
            mouseOverView.mouseOverColor = isSelected || isDragged ? NSColor.clear : NSColor.tabMouseOverColor
        }

        let showCloseButton = isSelected || closeButton.isFirstResponder
            || (isMouseOver && (!widthStage.isCloseButtonHidden || NSApp.isCommandPressed))
        closeButton.isHidden = !showCloseButton
        titleTextField.isHidden = widthStage.isTitleHidden && faviconImageView.image != nil
        faviconImageView.isHidden = widthStage.isTitleHidden && !closeButton.isHidden
        updateSeparatorView()

        permissionLeadingConstraint.isActive = !(faviconImageView.isHidden || permissionButton.isHidden)
        permissionTrailingConstraint.isActive = !(closeButton.isHidden || permissionButton.isHidden)
        closeButtonTrailingConstraint.isActive = widthStage.isFaviconCentered || (showCloseButton && !permissionButton.isHidden)

        faviconWrapperViewCenterConstraint.priority = titleTextField.isHidden ? .defaultHigh : .defaultLow
        faviconWrapperViewLeadingConstraint.priority = titleTextField.isHidden ? .defaultLow : .defaultHigh

        updateTitleTextFieldMask()
    }

    private var usedPermissions = Permissions() {
        didSet {
            updateUsedPermissions()
            updateTitleTextFieldMask()
        }
    }
    private func updateUsedPermissions() {
        if usedPermissions.camera.isActive {
            permissionButton.image = .cameraActiveImage
        } else if usedPermissions.microphone.isActive {
            permissionButton.image = .micActiveImage
        } else if usedPermissions.camera.isPaused {
            permissionButton.image = .cameraBlockedImage
        } else if usedPermissions.microphone.isPaused {
            permissionButton.image = .micBlockedImage
        } else {
            permissionButton.image = nil
            permissionButton.isHidden = true
            permissionLeadingConstraint.isActive = false
            return
        }
        permissionButton.isHidden = false
        permissionLeadingConstraint.isActive = true
        permissionTrailingConstraint.isActive = true
    }

    private func updateSeparatorView() {
        rightSeparatorView.isHidden = isSelected || isDragged || isSeparatorHidden
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
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
    }

}

extension TabBarViewItem: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let duplicateMenuItem = NSMenuItem(title: UserText.duplicateTab, action: #selector(duplicateAction(_:)), keyEquivalent: "")
        duplicateMenuItem.target = self
        menu.addItem(duplicateMenuItem)

        menu.addItem(NSMenuItem.separator())

        let bookmarkMenuItem = NSMenuItem(title: UserText.bookmarkThisPage, action: #selector(bookmarkThisPageAction(_:)), keyEquivalent: "")
        bookmarkMenuItem.target = self
        menu.addItem(bookmarkMenuItem)

        if let url = currentURL, url.canFireproof {
            let menuItem: NSMenuItem

            if FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "") {
                menuItem = NSMenuItem(title: UserText.removeFireproofing, action: #selector(removeFireproofingAction(_:)), keyEquivalent: "")
            } else {
                menuItem = NSMenuItem(title: UserText.fireproofSite, action: #selector(fireproofSiteAction(_:)), keyEquivalent: "")
            }

            menuItem.target = self
            menu.addItem(menuItem)
            menu.addItem(NSMenuItem.separator())
        }

        let closeMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(close(_:)), keyEquivalent: "")
        closeMenuItem.target = self
        menu.addItem(closeMenuItem)

        let otherItemsState = delegate?.otherTabBarViewItemsState(for: self) ?? .init(hasItemsToTheLeft: true,
                                                                                      hasItemsToTheRight: true)

        updateWithTabsToTheSides(menu, otherItemsState)

        let moveToNewWindowMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(moveToNewWindowAction(_:)), keyEquivalent: "")
        moveToNewWindowMenuItem.target = self
        menu.addItem(moveToNewWindowMenuItem)
    }

    private func updateWithTabsToTheSides(_ menu: NSMenu, _ otherItemsState: OtherTabBarViewItemsState) {
        if otherItemsState.hasItemsToTheLeft || otherItemsState.hasItemsToTheRight {
            let closeOtherMenuItem = NSMenuItem(title: UserText.closeOtherTabs, action: #selector(closeOtherAction(_:)), keyEquivalent: "")
            closeOtherMenuItem.target = self
            menu.addItem(closeOtherMenuItem)
        }

        if otherItemsState.hasItemsToTheRight {
            let closeTabsToTheRightMenuItem = NSMenuItem(title: UserText.closeTabsToTheRight,
                                                         action: #selector(closeToTheRightAction(_:)),
                                                         keyEquivalent: "")
            closeTabsToTheRightMenuItem.target = self
            menu.addItem(closeTabsToTheRightMenuItem)
        }

    }

}

extension TabBarViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
        self.isMouseOver = isMouseOver
        if isMouseOver {
            commandPressedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.updateSubviews()
                return event
            }
        }
        view.needsLayout = true
    }

}

extension TabBarViewItem: MouseClickViewDelegate {

    func mouseClickView(_ mouseClickView: MouseClickView, otherMouseDownEvent: NSEvent) {
        // close on middle-click
        guard otherMouseDownEvent.buttonNumber == 2 else { return }

        guard let indexPath = self.indexPath else {
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
        case standard = 32
    }

    enum Width: CGFloat {
        case minimum = 50
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

private extension NSImage {
    static let cameraActiveImage = NSImage(named: "Camera-Tab-Active")
    static let cameraBlockedImage = NSImage(named: "Camera-Tab-Blocked")

    static let micActiveImage = NSImage(named: "Microphone-Active")
    static let micBlockedImage = NSImage(named: "Microphone-Icon")
}
