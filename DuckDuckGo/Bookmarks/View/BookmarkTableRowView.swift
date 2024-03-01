//
//  BookmarkTableRowView.swift
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

final class BookmarkTableRowView: NSTableRowView {

    var onSelectionChanged: (() -> Void)?

    var hasPrevious = false {
        didSet {
            needsDisplay = true
        }
    }

    var hasNext = false {
        didSet {
            needsDisplay = true
        }
    }

    var mouseInside: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    override var isSelected: Bool {
        didSet {
            if mouseInside {
                onSelectionChanged?()
            }
        }
    }

    private var trackingArea: NSTrackingArea?

    override func drawBackground(in dirtyRect: NSRect) {
        backgroundColor.setFill()
        bounds.fill()

        if mouseInside {
            let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
            NSColor.rowHover.setFill()
            path.fill()
        }

        if isSelected {
            drawSelection(in: dirtyRect)
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        var roundedCorners = [NSBezierPath.Corners]()

        if !hasPrevious {
            roundedCorners.append(.topLeft)
            roundedCorners.append(.topRight)
        }

        if !hasNext {
            roundedCorners.append(.bottomLeft)
            roundedCorners.append(.bottomRight)
        }

        let path = NSBezierPath(roundedRect: dirtyRect, forCorners: roundedCorners, cornerRadius: 6)
        NSColor.selectedContentBackgroundColor.setFill()
        path.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        ensureTrackingArea()
        if !trackingAreas.contains(trackingArea!) {
            addTrackingArea(trackingArea!)
        }
    }

    func ensureTrackingArea() {
        if trackingArea == nil {
            trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .normal
    }

}
