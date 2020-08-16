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

}

class TabBarViewItem: NSCollectionViewItem {

    enum Height: CGFloat {
        case standard = 32
    }

    enum Width: CGFloat {
        case minimum = 80
        case maximum = 240
    }

    enum EffectViewTrailingSpace: CGFloat {
        case withCloseButton = 17
        case withoutCloseButton = 0
    }

    enum TitleTrailingSpace: CGFloat {
        case withCloseButton = 20
        case withoutCloseButton = 3
    }

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

    static var menu: NSMenu {
        let menu = NSMenu()
        let menuItem = NSMenuItem(title: "Close Tab", action: #selector(closeButtonAction(_:)), keyEquivalent: "")
        menu.addItem(menuItem)
        return menu
    }

    @IBOutlet weak var faviconImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var effectViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTextFieldTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var closeButtonFadeImageView: NSImageView!
    @IBOutlet weak var closeButtonFadeEffectView: NSVisualEffectView!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var bottomCornersView: ColorView!
    @IBOutlet weak var loadingView: TabLoadingView!

    private var cancelables = Set<AnyCancellable>()

    weak var delegate: TabBarViewItemDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setView()
        setSubviews()
        setMenu()
        setEffectViewMask()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        setSubviews()
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                isDragged = false
            }
            setSubviews()
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        isDragged = true
        return super.draggingImageComponents
    }

    @IBAction func closeButtonAction(_ sender: NSButton) {
        delegate?.tabBarViewItemCloseAction(self)
    }

    func bind(tabViewModel: TabViewModel) {
        clearBindings()

        tabViewModel.$title.sink { title in
            self.titleTextField.stringValue = title
        }.store(in: &cancelables)

        tabViewModel.$favicon.sink { favicon in
            self.faviconImageView.image = favicon
        }.store(in: &cancelables)

        tabViewModel.$isLoading.sink { isLoading in
            if isLoading {
                self.loadingView.startAnimation()
            } else {
                self.loadingView.stopAnimation()
            }
        }.store(in: &cancelables)
    }

    func clear() {
        clearBindings()
        faviconImageView.image = nil
        titleTextField.stringValue = ""
    }

    private func setView() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.masksToBounds = false
    }

    private func clearBindings() {
        cancelables.forEach { (cancelable) in
            cancelable.cancel()
        }
    }

    private var isDragged = false {
        didSet {
            setSubviews()
        }
    }

    private func setSubviews() {
        let backgroundColor = isSelected || isDragged ? NSColor(named: "InterfaceBackgroundColor") : NSColor.clear

        view.layer?.backgroundColor = backgroundColor?.cgColor
        bottomCornersView.backgroundColor = backgroundColor

        rightSeparatorView.isHidden = isSelected || isDragged

        closeButton.isHidden = !isSelected && view.bounds.size.width == Width.minimum.rawValue
        effectViewTrailingConstraint.constant = closeButton.isHidden ?
            EffectViewTrailingSpace.withoutCloseButton.rawValue :
            EffectViewTrailingSpace.withCloseButton.rawValue
        titleTextFieldTrailingConstraint.constant = closeButton.isHidden ?
            TitleTrailingSpace.withoutCloseButton.rawValue :
            TitleTrailingSpace.withCloseButton.rawValue

        closeButtonFadeImageView.isHidden = !isSelected && !isDragged
        closeButtonFadeEffectView.isHidden = isSelected || isDragged
    }

    private func setMenu() {
        let menu = Self.menu
        menu.items.forEach { $0.target = self }
        view.menu = menu
    }

    private func setEffectViewMask() {
        closeButtonFadeEffectView.maskImage = NSImage(named: "TabCloseButtonFade")
    }

}
