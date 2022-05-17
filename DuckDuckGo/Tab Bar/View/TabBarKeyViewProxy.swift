//
//  TabBarKeyViewProxy.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import AppKit

final class TabBarViewItemProxy: NSView {
    weak var collectionView: TabBarCollectionView?

    let index: Int
    let position: Position

    enum Position {
        case first
        case second
        case beforeLast
        case last
    }

    init(collectionView: TabBarCollectionView, index: Int, position: Position) {
        self.collectionView = collectionView
        self.index = index
        self.position = position
        let frame = [.first, .second].contains(position)
            ? NSRect(x: 0, y: 0, width: 1, height: collectionView.frame.height)
            : NSRect(x: collectionView.enclosingScrollView!.frame.width - 1, y: 0, width: 1, height: collectionView.frame.height)
        super.init(frame: frame)

        collectionView.enclosingScrollView?.addSubview(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        NSApp.isFullKeyboardAccessEnabled && self.isVisible
    }

    override var canBecomeKeyView: Bool {
        NSApp.isFullKeyboardAccessEnabled && self.isVisible
    }

    override func becomeFirstResponder() -> Bool {
        guard let collectionView = collectionView else { return false }
        self.removeFromSuperview()

        collectionView.scroll(to: index) { [index, position] _ in
            guard let item = collectionView.item(at: IndexPath(item: index, section: 0))
            else { return }

            switch position {
            // Navigating backward to a Tab's button
            case .second, .last:
                guard let btn = item.view.subviews.filter({ ($0 as? NSButton)?.canBecomeKeyView == true }).last else { fallthrough }
                btn.makeMeFirstResponder()
            // Navigating forward to the Tab
            case .first, .beforeLast:
                item.view.makeMeFirstResponder()
            }
        }
        return false
    }

}
