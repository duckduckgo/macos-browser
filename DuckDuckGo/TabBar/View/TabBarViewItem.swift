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

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem)
    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem)

}

class TabBarViewItem: NSCollectionViewItem {

    enum Height: CGFloat {
        case standard = 32
    }

    enum Width: CGFloat {
        case minimum = 80
        case maximum = 240
    }

    enum TextFieldMaskGradientSize: CGFloat {
        case width = 6
        case trailingSpace = 0
        case trailingSpaceWithButton = 20
    }

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

    static var menu: NSMenu {
        let menu = NSMenu()

        let duplicateMenuItem = NSMenuItem(title: "Duplicate Tab", action: #selector(duplicateAction(_:)), keyEquivalent: "")
        menu.addItem(duplicateMenuItem)
        menu.addItem(NSMenuItem.separator())
        let closeMenuItem = NSMenuItem(title: "Close Tab", action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        menu.addItem(closeMenuItem)
        let closeOtherMenuItem = NSMenuItem(title: "Close Other Tabs", action: #selector(closeOtherAction(_:)), keyEquivalent: "")
        menu.addItem(closeOtherMenuItem)
        return menu
    }

    @IBOutlet weak var faviconImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var closeButton: MouseOverButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var loadingView: TabLoadingView!
    @IBOutlet weak var mouseOverView: MouseOverView!

    private let titleTextFieldMaskLayer = CAGradientLayer()

    private var cancelables = Set<AnyCancellable>()

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

    @IBAction func closeButtonAction(_ sender: NSButton) {
        delegate?.tabBarViewItemCloseAction(self)
    }

    @objc func closeOtherAction(_ sender: NSButton) {
        delegate?.tabBarViewItemCloseOtherAction(self)
    }

    func subscribe(to tabViewModel: TabViewModel) {
        clearSubscriptions()

        tabViewModel.$title.sink { [weak self] title in
            self?.titleTextField.stringValue = title
        }.store(in: &cancelables)

        tabViewModel.$favicon.sink { [weak self] favicon in
            self?.faviconImageView.image = favicon
        }.store(in: &cancelables)

        tabViewModel.$isLoading.sink { [weak self] isLoading in
            if isLoading {
                self?.loadingView.startAnimation()
            } else {
                self?.loadingView.stopAnimation()
            }
        }.store(in: &cancelables)
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
        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer?.masksToBounds = true
    }

    private func clearSubscriptions() {
        cancelables.forEach { (cancelable) in
            cancelable.cancel()
        }
    }

    private func updateSubviews() {
        let backgroundColor = isSelected || isDragged ? NSColor(named: "InterfaceBackgroundColor") : NSColor.clear
        view.layer?.backgroundColor = backgroundColor?.cgColor
        mouseOverView.mouseOverColor = isSelected || isDragged ? NSColor.clear : NSColor(named: "TabMouseOverColor")

        rightSeparatorView.isHidden = isSelected || isDragged
        closeButton.isHidden = !isSelected && !isDragged && view.bounds.size.width == Width.minimum.rawValue
    }

    private func setupMenu() {
        let menu = Self.menu
        menu.items.forEach { $0.target = self }
        view.menu = menu
    }

    private func updateTitleTextFieldMask() {
        guard let titleTextFieldLayer = titleTextField.layer else {
            os_log("TabBarViewItem: Title text field has no layer", log: OSLog.Category.general, type: .error)
            return
        }

        if titleTextFieldLayer.mask == nil {
            titleTextFieldLayer.mask = titleTextFieldMaskLayer
            titleTextFieldMaskLayer.colors = [NSColor.white.cgColor, NSColor.clear.cgColor]
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0)

        titleTextFieldMaskLayer.frame = titleTextFieldLayer.bounds

        let gradientPadding: CGFloat = closeButton.isHidden ?
            TextFieldMaskGradientSize.trailingSpace.rawValue : TextFieldMaskGradientSize.trailingSpaceWithButton.rawValue
        let gradientWidth: CGFloat = TextFieldMaskGradientSize.width.rawValue
        let startPointX = (titleTextFieldMaskLayer.bounds.width - (gradientPadding + gradientWidth)) / titleTextFieldMaskLayer.bounds.width
        let endPointX = (titleTextFieldMaskLayer.bounds.width - gradientPadding) / titleTextFieldMaskLayer.bounds.width

        titleTextFieldMaskLayer.startPoint = CGPoint(x: startPointX, y: 0.5)
        titleTextFieldMaskLayer.endPoint = CGPoint(x: endPointX, y: 0.5)

        CATransaction.commit()
    }

}
