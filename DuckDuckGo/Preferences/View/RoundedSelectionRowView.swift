//
//  RoundedSelectionRowView.swift
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

import Foundation

final class RoundedSelectionRowView: NSTableRowView {

    var insets = NSEdgeInsets()

    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            var selectionRect = self.bounds

            selectionRect.origin.x += insets.left
            selectionRect.origin.y += insets.top
            selectionRect.size.width -= (insets.left + insets.right)
            selectionRect.size.height -= (insets.top + insets.bottom)

            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            NSColor(named: "RowHoverColor")!.setFill()
            path.fill()
        }
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .light
    }

}
