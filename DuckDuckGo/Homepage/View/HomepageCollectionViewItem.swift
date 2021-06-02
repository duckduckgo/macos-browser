//
//  HomepageCollectionViewItem.swift
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

protocol HomepageCollectionViewItemDelegate: AnyObject {

    func homepageCollectionViewItemOpenInNewTabAction(_ homepageCollectionViewItem: HomepageCollectionViewItem)
    func homepageCollectionViewItemOpenInNewWindowAction(_ homepageCollectionViewItem: HomepageCollectionViewItem)
    func homepageCollectionViewItemEditAction(_ homepageCollectionViewItem: HomepageCollectionViewItem)
    func homepageCollectionViewItemRemoveAction(_ homepageCollectionViewItem: HomepageCollectionViewItem)

}

final class HomepageCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "HomepageCollectionViewItem")

    enum Size {
        static let width = 92
        static let height = 92
    }

    private enum Constants {
        static let textFieldCornerRadius: CGFloat = 4
    }

    weak var delegate: HomepageCollectionViewItemDelegate?
    var isPlaceholder: Bool = false

    @IBOutlet weak var wideBorderView: ColorView!
    @IBOutlet weak var narrowBorderView: ColorView!
    @IBOutlet weak var croppingView: ColorView!
    @IBOutlet weak var overlayView: ColorView!
    @IBOutlet weak var faviconImageView: NSImageView!
    @IBOutlet weak var representingCharacterTextField: NSTextField!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var mouseOverView: MouseOverView!

    override func awakeFromNib() {
        super.awakeFromNib()

        setupView()
        state = .normal
    }

    func set(bookmarkViewModel: BookmarkViewModel, isPlaceholder: Bool = false) {
        self.isPlaceholder = isPlaceholder

        if let favicon = bookmarkViewModel.entity.asBookmark?.favicon {
            faviconImageView.image = favicon
            faviconImageView.layer?.backgroundColor = NSColor.clear.cgColor
            representingCharacterTextField.isHidden = true
        } else {
            faviconImageView.image = nil
            faviconImageView.layer?.backgroundColor = bookmarkViewModel.representingColor.cgColor
            representingCharacterTextField.isHidden = false
            representingCharacterTextField.stringValue = bookmarkViewModel.representingCharacter
        }

        titleTextField.stringValue = bookmarkViewModel.entity.asBookmark!.title

        setupMenu()
    }

    func setAddFavourite() {
        NSAppearance.withAppAppearance {
            faviconImageView.image = NSImage(named: "Add")
            faviconImageView.layer?.backgroundColor = NSColor.homepageAddItemFillColor.cgColor
            representingCharacterTextField.isHidden = true
            titleTextField.stringValue = UserText.addFavorite
        }

        view.menu = nil
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        state = .normal
    }

    private func setupView() {
        mouseOverView.delegate = self
        titleTextField.wantsLayer = true
        titleTextField.layer?.cornerRadius = Constants.textFieldCornerRadius
        faviconImageView.wantsLayer = true
    }

    private var isMouseOver = false

    // MARK: - State

    private enum State {
        case normal
        case hover
        case active
    }

    private var state: State = .normal {
        didSet {
            NSAppearance.withAppAppearance {
                let wideBorderColor: NSColor, narrowBorderColor: NSColor
                switch state {
                case .normal:
                    wideBorderColor = NSColor.clear
                    narrowBorderColor = NSColor.homepageFaviconBorderColor
                case .hover:
                    wideBorderColor = NSColor.homepageFaviconHoverColor
                    narrowBorderColor = NSColor.clear
                case .active:
                    wideBorderColor = NSColor.homepageFaviconActiveColor
                    narrowBorderColor = NSColor.clear
                }

                wideBorderView.backgroundColor = wideBorderColor
                narrowBorderView.backgroundColor = narrowBorderColor
                titleTextField.layer?.backgroundColor = wideBorderColor.cgColor
                overlayView.isHidden = state != .active
            }
        }
    }

    override var isSelected: Bool {
        didSet {
            switch state {
            case .normal: if isSelected { state = .active }
            case .hover: if isSelected { state = .active }
            case .active: if !isSelected { state = isMouseOver ? .hover : .normal }
            }
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: UserText.openInNewTab,
                                action: #selector(openInNewTab(_:)),
                                target: self,
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: UserText.openInNewWindow,
                                action: #selector(openInNewWindow(_:)),
                                target: self,
                                keyEquivalent: ""))

        if !isPlaceholder {
            menu.addItem(NSMenuItem.separator())

            menu.addItem(NSMenuItem(title: UserText.edit,
                                action: #selector(edit(_:)),
                                target: self,
                                keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: UserText.remove,
                                action: #selector(remove(_:)),
                                target: self,
                                keyEquivalent: ""))
        }

        menu.delegate = self
        view.menu = menu
    }

    @objc func openInNewTab(_ sender: NSButton) {
        delegate?.homepageCollectionViewItemOpenInNewTabAction(self)
    }

    @objc func openInNewWindow(_ sender: NSButton) {
        delegate?.homepageCollectionViewItemOpenInNewWindowAction(self)
    }

    @objc func edit(_ sender: NSButton) {
        delegate?.homepageCollectionViewItemEditAction(self)
    }

    @objc func remove(_ sender: NSButton) {
        delegate?.homepageCollectionViewItemRemoveAction(self)
    }

}

extension HomepageCollectionViewItem: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        self.isMouseOver = isMouseOver
        switch state {
        case .normal: if isMouseOver { state = .hover }
        case .hover: if !isMouseOver { state = .normal }
        case .active: break
        }
    }

}

extension HomepageCollectionViewItem: NSMenuDelegate {

    func menuDidClose(_ menu: NSMenu) {
        state = .normal
    }
}

fileprivate extension NSColor {

    static let homepageFaviconBorderColor = NSColor(named: "HomepageFaviconBorderColor")!
    static let homepageFaviconHoverColor = NSColor(named: "HomepageFaviconHoverColor")!
    static let homepageFaviconActiveColor = NSColor(named: "HomepageFaviconActiveColor")!
    static let homepageAddItemFillColor = NSColor(named: "HomepageAddItemFillColor")!

}
