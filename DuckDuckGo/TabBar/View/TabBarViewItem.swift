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

protocol TabBarViewItemDelegate: AnyObject {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool)

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem)

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> (hasItemsToTheLeft: Bool, hasItemsToTheRight: Bool)

}

final class TabBarViewItem: NSCollectionViewItem {

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

    var widthStage: WidthStage {
        if isSelected || isDragged {
            return .full
        } else {
            return WidthStage(width: view.bounds.size.width)
        }
    }

    enum TextFieldMaskGradientSize: CGFloat {
        case width = 6
        case trailingSpace = 0
        case trailingSpaceWithButton = 20
    }

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

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

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var loadingView: TabLoadingView!
    @IBOutlet weak var mouseOverView: MouseOverView!
    @IBOutlet weak var mouseClickView: MouseClickView!
    @IBOutlet weak var tabLoadingViewCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var tabLoadingViewLeadingConstraint: NSLayoutConstraint!

    private let titleTextFieldMaskLayer = CAGradientLayer()

    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: TabBarViewItemDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        updateSubviews()
        setupMenu()
        updateTitleTextFieldMask()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateSubviews()
        updateTitleTextFieldMask()
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                isDragged = false
            }
            updateSubviews()
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

    @objc func closeOtherAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseOtherAction(self)
    }

    @objc func closeToTheRightAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemCloseToTheRightAction(self)
    }

    @objc func moveToNewWindowAction(_ sender: NSMenuItem) {
        delegate?.tabBarViewItemMoveToNewWindowAction(self)
    }

    func subscribe(to tabViewModel: TabViewModel) {
        clearSubscriptions()

        tabViewModel.$title.sink { [weak self] title in
            self?.titleTextField.stringValue = title
        }.store(in: &cancellables)

        tabViewModel.$favicon.sink { [weak self] favicon in
            self?.faviconImageView.image = favicon
        }.store(in: &cancellables)

        tabViewModel.tab.$url.sink { [weak self] url in
            self?.currentURL = url
        }.store(in: &cancellables)
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

        updateSeparatorView()
        closeButton.isHidden = !isSelected && !isDragged && widthStage.isCloseButtonHidden
        titleTextField.isHidden = widthStage.isTitleHidden

        tabLoadingViewCenterConstraint.priority = widthStage.isTitleHidden && widthStage.isCloseButtonHidden ? .defaultHigh : .defaultLow
        tabLoadingViewLeadingConstraint.priority = widthStage.isTitleHidden && widthStage.isCloseButtonHidden ? .defaultLow : .defaultHigh
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
        let gradientPadding: CGFloat = closeButton.isHidden ?
            TextFieldMaskGradientSize.trailingSpace.rawValue : TextFieldMaskGradientSize.trailingSpaceWithButton.rawValue
        titleTextField.gradient(width: TextFieldMaskGradientSize.width.rawValue,
                                trailingPadding: gradientPadding)
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

        let otherItemsState = delegate?.otherTabBarViewItemsState(for: self) ?? (hasItemsToTheLeft: true, hasItemsToTheRight: true)

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

        let moveToNewWindowMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(moveToNewWindowAction(_:)), keyEquivalent: "")
        moveToNewWindowMenuItem.target = self
        menu.addItem(moveToNewWindowMenuItem)
    }

}

extension TabBarViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
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
