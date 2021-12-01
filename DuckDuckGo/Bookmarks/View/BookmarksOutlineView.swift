//
//  BookmarksOutlineView.swift
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

import AppKit

extension NSDragOperation {

    static let none = NSDragOperation([])

}

final class BookmarksOutlineView: NSOutlineView {

    var lastRow: RoundedSelectionRowView?

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        let frame = super.frameOfOutlineCell(atRow: row)

        guard let node = item(atRow: row) as? BookmarkNode else {
            return frame
        }

        if node.representedObject is SpacerNode {
            return .zero
        }

        guard node.representedObject is PseudoFolder else {
            return frame
        }

        if node.childNodes.isEmpty {
            return .zero
        } else {
            return frame
        }
    }

    override func awakeFromNib() {
        guard let scrollView = enclosingScrollView else { fatalError() }

        let trackingArea = NSTrackingArea(rect: scrollView.frame,
                                          options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                          owner: self,
                                          userInfo: nil)
        scrollView.addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        lastRow?.highlight = false
        let point = convert(event.locationInWindow, to: nil)
        let row = row(at: point)
        guard row >= 0, let rowView = rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView else { return }
        let item = item(atRow: row) as? BookmarkNode
        rowView.highlight = !(item?.representedObject is SpacerNode)
        lastRow = rowView
    }
}
