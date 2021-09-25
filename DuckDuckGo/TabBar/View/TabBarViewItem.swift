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

struct OtherTabBarViewItemsState {

    let hasItemsToTheLeft: Bool
    let hasItemsToTheRight: Bool
    let hasBurnerTabs: Bool

}

protocol TabBarViewItemDelegate: AnyObject {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool)

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemConvertToStandard(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseBurnerTabs(_ tabBarViewItem: TabBarViewItem)

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState

}

final class TabBarViewItem: NSCollectionViewItem {

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

    @IBOutlet weak var faviconImageView: NSImageView! {
        didSet {
            faviconImageView.applyFaviconStyle()
        }
    }
    @IBOutlet weak var permissionButton: NSButton!

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var mouseOverView: MouseOverView!
    @IBOutlet weak var mouseClickView: MouseClickView!
    @IBOutlet weak var faviconWrapperViewCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var faviconWrapperViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var permissionCloseButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var tabLoadingPermissionLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var closeButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var burnerTabIndicator: ColorView!

    private let titleTextFieldMaskLayer = CAGradientLayer()

    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: TabBarViewItemDelegate?

    var isBurnerTab = false
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
            burnerTabIndicator.backgroundColor = isSelected ? NSColor.burnerIndicatorSelectedColor : NSColor.burnerIndicatorUnselectedColor
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

    @IBAction func closeButtonAction(_ sender: NSButton) {
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

    @objc func convertToStandardTab(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemConvertToStandard(self)
    }

    @objc func closeBurnerTabs(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseBurnerTabs(self)
    }

    func subscribe(to tabViewModel: TabViewModel) {
        clearSubscriptions()

        isBurnerTab = tabViewModel.tab.tabStorageType == .burner

        closeButton.image = tabViewModel.tab.tabStorageType == .burner ? NSImage(named: "BurnClose") : NSImage(named: "Close")
        burnerTabIndicator.isHidden = tabViewModel.tab.tabStorageType != .burner

        tabViewModel.$title.sink { [weak self] title in
            self?.titleTextField.stringValue = title
        }.store(in: &cancellables)

        tabViewModel.$favicon.sink { [weak self] favicon in
            self?.faviconImageView.image = favicon
        }.store(in: &cancellables)

        tabViewModel.tab.$content.sink { [weak self] content in
            self?.currentURL = content.url
        }.store(in: &cancellables)

        tabViewModel.$usedPermissions.weakAssign(to: \.usedPermissions, on: self).store(in: &cancellables)
    }

    func clear() {
        clearSubscriptions()
        faviconImageView.image = nil
        titleTextField.stringValue = ""
    }

    private var isDragged = false {
        didSet {
            updateSubviews()
        }
    }

    private func setupView() {
        mouseOverView.delegate = self
        mouseClickView.delegate = self

        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer?.masksToBounds = true
    }

    private func clearSubscriptions() {
        cancellables.forEach { (cancellable) in
            cancellable.cancel()
        }
    }

    private func updateSubviews() {
        NSAppearance.withAppAppearance {
            let backgroundColor = isSelected || isDragged ? NSColor.interfaceBackgroundColor : NSColor.clear
            view.layer?.backgroundColor = backgroundColor.cgColor
            mouseOverView.mouseOverColor = isSelected || isDragged ? NSColor.clear : NSColor.tabMouseOverColor
        }

        let showCloseButton = isMouseOver || isSelected
        closeButton.isHidden = !showCloseButton
        updateSeparatorView()
        permissionCloseButtonTrailingConstraint.isActive = !closeButton.isHidden
        titleTextField.isHidden = widthStage.isTitleHidden

        faviconWrapperViewCenterConstraint.priority = widthStage.isTitleHidden ? .defaultHigh : .defaultLow
        faviconWrapperViewLeadingConstraint.priority = widthStage.isTitleHidden ? .defaultLow : .defaultHigh
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

        let closeMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        closeMenuItem.target = self
        menu.addItem(closeMenuItem)

        let otherItemsState = delegate?.otherTabBarViewItemsState(for: self) ?? .init(hasItemsToTheLeft: true,
                                                                                      hasItemsToTheRight: true,
                                                                                      hasBurnerTabs: false)

        updateWithTabsToTheSides(menu, otherItemsState)

        let moveToNewWindowMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(moveToNewWindowAction(_:)), keyEquivalent: "")
        moveToNewWindowMenuItem.target = self
        menu.addItem(moveToNewWindowMenuItem)

        updateWithBurnerTabItems(menu, otherItemsState)
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

    private func updateWithBurnerTabItems(_ menu: NSMenu, _ otherItemsState: OtherTabBarViewItemsState) {
        if isBurnerTab || otherItemsState.hasBurnerTabs {
            menu.addItem(NSMenuItem.separator())
        }

        if isBurnerTab {
            menu.addItem(NSMenuItem(title: UserText.convertToTab, action: #selector(convertToStandardTab(_:)), target: self, keyEquivalent: ""))
        }

        if otherItemsState.hasBurnerTabs {
            menu.addItem(NSMenuItem(title: UserText.closeAllBurnerTabs, action: #selector(closeBurnerTabs(_:)), target: self, keyEquivalent: ""))
        }
    }

}

extension TabBarViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
        self.isMouseOver = isMouseOver
        view.needsLayout = true
    }

}

extension TabBarViewItem: MouseClickViewDelegate {

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
        case standard = 32
    }

    enum Width: CGFloat {
        case minimum = 50
        case minimumSelected = 120
        case maximum = 240
    }

    enum WidthStage {
        case full
        case withoutTitle

        init(width: CGFloat) {
            switch width {
            case 0..<61: self = .withoutTitle
            default: self = .full
            }
        }

        var isTitleHidden: Bool { self == .withoutTitle }
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
