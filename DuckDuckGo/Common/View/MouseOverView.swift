//
//  MouseOverView.swift
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

class MouseOverView: NSView {

    @IBInspectable var mouseOverColor: NSColor? {
        didSet {
            setBackgroundColor()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        removeAddTrackingArea()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        removeAddTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseOver = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseOver = false
        super.mouseExited(with: event)
    }

    private var isMouseOver = false {
        didSet {
            setBackgroundColor()
        }
    }

    private func setBackgroundColor() {
        guard let mouseOverColor = mouseOverColor else {
            layer?.backgroundColor = NSColor.clear.cgColor
            return
        }

        if isMouseOver {
            layer?.backgroundColor = mouseOverColor.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func removeAddTrackingArea() {
        trackingAreas.forEach {
            removeTrackingArea($0)
        }

        let trackingArea = NSTrackingArea(rect: frame,
                                          options: [.mouseEnteredAndExited,
                                                    .activeInKeyWindow,
                                                    .enabledDuringMouseDrag],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)
        setIsMouseOver()
    }

    //swiftlint:disable legacy_nsgeometry_functions
    private func setIsMouseOver() {
        guard let window = window else {
            os_log("MouseOverView: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        let mouseLocation = window.mouseLocationOutsideOfEventStream
        if NSPointInRect(mouseLocation, bounds) {
            isMouseOver = true
        } else {
            isMouseOver = false
        }
    }
    //swiftlint:enable legacy_nsgeometry_functions

}
