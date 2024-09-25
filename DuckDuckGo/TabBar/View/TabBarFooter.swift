//
//  TabBarFooter.swift
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

final class TabBarFooter: NSView, NSCollectionViewElement {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarFooter")

    let addButton = MouseOverButton(image: .add, target: nil, action: #selector(TabBarViewController.addButtonAction))

    var target: MouseOverButtonDelegate? {
        get {
            addButton.delegate
        }
        set {
            addButton.target = newValue
            addButton.delegate = newValue
        }
    }

    var isEnabled: Bool {
        get {
            addButton.isEnabled
        }
        set {
            addButton.isEnabled = newValue
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)

        identifier = Self.identifier
        translatesAutoresizingMaskIntoConstraints = false

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.isBordered = false
        addButton.bezelStyle = .shadowlessSquare
        addButton.cornerRadius = 4
        addButton.normalTintColor = .button
        addButton.mouseDownColor = .buttonMouseDown
        addButton.mouseOverColor = .buttonMouseOver
        addButton.imagePosition = .imageOnly
        addButton.imageScaling = .scaleNone
        addButton.registerForDraggedTypes([.string])
        toolTip = UserText.newTabTooltip

        addSubview(addButton)
     }

    required init?(coder: NSCoder) {
        fatalError("TabBarFooter: Bad initializer")
    }

    override func layout() {
        super.layout()

        addButton.frame = NSRect(x: ((bounds.width - 28) * 0.5).rounded(), y: ((bounds.height - 28) * 0.5).rounded(), width: 28, height: 28)
    }

}

#if DEBUG
extension TabBarFooter {
    final class PreviewViewController: NSViewController {
        override func loadView() {
            view = NSView()
            view.addSubview(TabBarFooter(frame: NSRect(x: 4, y: 2, width: 32, height: 32)))
        }
    }
}
@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 40, height: 40)) {
    TabBarFooter.PreviewViewController()
        ._preview_hidingWindowControlsOnAppear()
}
#endif
