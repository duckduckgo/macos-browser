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
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem)

}

class TabBarViewItem: NSCollectionViewItem {

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

    var tabBarViewItemMenu: NSMenu {
        let menu = NSMenu()

        let duplicateMenuItem = NSMenuItem(title: UserText.duplicateTab, action: #selector(duplicateAction(_:)), keyEquivalent: "")
        menu.addItem(duplicateMenuItem)

        menu.addItem(NSMenuItem.separator())

        let bookmarkMenuItem = NSMenuItem(title: UserText.bookmarkThisPage, action: #selector(bookmarkThisPageAction(_:)), keyEquivalent: "")
        menu.addItem(bookmarkMenuItem)

        if let url = currentURL, url.canFireproof {
            let menuItem: NSMenuItem

            if FireproofDomains.shared.isAllowed(fireproofDomain: url.host ?? "") {
                menuItem = NSMenuItem(title: UserText.removeFireproofing, action: #selector(removeFireproofingAction(_:)), keyEquivalent: "")
            } else {
                menuItem = NSMenuItem(title: UserText.fireproofSite, action: #selector(fireproofSiteAction(_:)), keyEquivalent: "")
            }

            menu.addItem(menuItem)
            menu.addItem(NSMenuItem.separator())
        }

        let closeMenuItem = NSMenuItem(title: UserText.closeTab, action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        menu.addItem(closeMenuItem)

        let closeOtherMenuItem = NSMenuItem(title: UserText.closeOtherTabs, action: #selector(closeOtherAction(_:)), keyEquivalent: "")
        menu.addItem(closeOtherMenuItem)

        let moveToNewWindowMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow, action: #selector(moveToNewWindowAction(_:)), keyEquivalent: "")
        menu.addItem(moveToNewWindowMenuItem)

        return menu
    }

    @IBOutlet weak var faviconImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var loadingView: TabLoadingView!
    @IBOutlet weak var mouseOverView: MouseOverView!
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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(setupMenu),
                                               name: FireproofDomains.Constants.allowedDomainsChangedNotification,
                                               object: nil)
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

    @objc func bookmarkThisPageAction(_ sender: NSButton) {
        delegate?.tabBarViewItemBookmarkThisPageAction(self)
    }

    @IBAction func closeButtonAction(_ sender: NSButton) {
        delegate?.tabBarViewItemCloseAction(self)
    }

    @objc func closeOtherAction(_ sender: NSButton) {
        delegate?.tabBarViewItemCloseOtherAction(self)
    }

    @objc func moveToNewWindowAction(_ sender: NSButton) {
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
            self?.setupMenu()
        }.store(in: &cancellables)

        tabViewModel.$isLoading.sink { [weak self] isLoading in
            if isLoading {
                self?.loadingView.startAnimation()
            } else {
                self?.loadingView.stopAnimation()
            }
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

        rightSeparatorView.isHidden = isSelected || isDragged
        closeButton.isHidden = !isSelected && !isDragged && widthStage.isCloseButtonHidden
        titleTextField.isHidden = widthStage.isTitleHidden

        tabLoadingViewCenterConstraint.priority = widthStage.isTitleHidden && widthStage.isCloseButtonHidden ? .defaultHigh : .defaultLow
        tabLoadingViewLeadingConstraint.priority = widthStage.isTitleHidden && widthStage.isCloseButtonHidden ? .defaultLow : .defaultHigh
    }

    @objc func setupMenu() {
        let menu = self.tabBarViewItemMenu
        menu.items.forEach { $0.target = self }
        view.menu = menu
    }

    private func updateTitleTextFieldMask() {
        let gradientPadding: CGFloat = closeButton.isHidden ?
            TextFieldMaskGradientSize.trailingSpace.rawValue : TextFieldMaskGradientSize.trailingSpaceWithButton.rawValue
        titleTextField.gradient(width: TextFieldMaskGradientSize.width.rawValue,
                                trailingPadding: gradientPadding)
    }

}

extension TabBarViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        delegate?.tabBarViewItem(self, isMouseOver: isMouseOver)
    }

}
