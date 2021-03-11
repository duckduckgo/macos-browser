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

class HomepageCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "HomepageCollectionViewItem")

    enum Size {
        static let width = 92
        static let height = 92
    }

    private enum Constants {
        static let textFieldCornerRadius: CGFloat = 4
    }

    @IBOutlet weak var wideBorderView: ColorView!
    @IBOutlet weak var narrowBorderView: ColorView!
    @IBOutlet weak var croppingView: ColorView!
    @IBOutlet weak var faviconImageView: BorderImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var mouseOverView: MouseOverView!

    override func awakeFromNib() {
        super.awakeFromNib()

        setupView()
        state = .normal
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            switch state {
            case .normal: if highlightState == .forSelection { state = .active }
            case .hover: if highlightState == .forSelection { state = .active }
            case .active: if highlightState != .forSelection { state = isMouseOver ? .hover : .normal }
            }
        }
    }

    func set(bookmark: Bookmark) {
        if let size = bookmark.favicon?.size,
           size.width >= CGFloat(Size.width),
           size.height >= CGFloat(Size.width) {
            faviconImageView.image = bookmark.favicon
        } else {
            faviconImageView.image = nil
        }

        titleTextField.stringValue = bookmark.title
    }

    func setAddFavourite() {
        faviconImageView.image = NSImage(named: "Add")
        titleTextField.stringValue = UserText.addFavorite
    }

    private func setupView() {
        mouseOverView.delegate = self
        titleTextField.wantsLayer = true
        titleTextField.layer?.cornerRadius = Constants.textFieldCornerRadius
    }

    private var isMouseOver: Bool = false

    // MARK: - State

    private enum State {
        case normal
        case hover
        case active
    }

    private var state: State = .normal {
        didSet {
            let wideBorderColor: NSColor, narrowBorderColor: NSColor, foregroundColor: NSColor
            switch state {
            case .normal:
                wideBorderColor = NSColor.clear
                narrowBorderColor = NSColor.homepageFaviconBorderColor
                foregroundColor = NSColor.clear
            case .hover:
                wideBorderColor = NSColor.homepageFaviconHoverColor
                narrowBorderColor = NSColor.clear
                foregroundColor = NSColor.clear
            case .active:
                wideBorderColor = NSColor.homepageFaviconActiveColor
                narrowBorderColor = NSColor.clear
                foregroundColor =  NSColor.homepageFaviconActiveColor
            }

            wideBorderView.backgroundColor = wideBorderColor
            narrowBorderView.backgroundColor = narrowBorderColor
            titleTextField.layer?.backgroundColor = wideBorderColor.cgColor
            //todo foreground
        }
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

fileprivate extension NSColor {

    static let homepageFaviconBorderColor = NSColor(named: "HomepageFaviconBorderColor")!
    static let homepageFaviconHoverColor = NSColor(named: "HomepageFaviconHoverColor")!
    static let homepageFaviconActiveColor = NSColor(named: "HomepageFaviconActiveColor")!

}
