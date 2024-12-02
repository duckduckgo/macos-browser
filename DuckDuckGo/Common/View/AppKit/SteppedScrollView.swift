//
//  SteppedScrollView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation

/// NSMenu-like stepped ScrollView
final class SteppedScrollView: NSScrollView {

    private var accumulatedDelta: CGFloat = 0
    private let stepSize: CGFloat

    init(frame: NSRect, stepSize: CGFloat) {
        self.stepSize = stepSize
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func scrollWheel(with event: NSEvent) {
        guard let documentView = self.documentView else { return }

        // Update the accumulated delta with the scroll event's deltaY
        accumulatedDelta += event.scrollingDeltaY * 2

        // Determine how many steps we need to scroll
        if abs(accumulatedDelta) >= stepSize {
            // Calculate the scroll amount
            let scrollAmount = CGFloat(Int(accumulatedDelta / stepSize)) * stepSize

            // Adjust the document view's scroll position
            let newScrollOrigin = NSPoint(x: documentView.visibleRect.origin.x, y: documentView.visibleRect.origin.y - scrollAmount)
            documentView.scroll(newScrollOrigin)

            // Reset the accumulated delta
            accumulatedDelta -= scrollAmount
        }
    }
}
