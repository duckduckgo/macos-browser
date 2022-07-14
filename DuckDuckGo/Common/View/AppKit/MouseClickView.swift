//
//  MouseClickView.swift
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

protocol MouseClickViewDelegate: AnyObject {

    func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent)
    func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent)
    func mouseClickView(_ mouseClickView: MouseClickView, rightMouseDownEvent: NSEvent)
    func mouseClickView(_ mouseClickView: MouseClickView, otherMouseDownEvent: NSEvent)

}

extension MouseClickViewDelegate {

    func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent) {}
    func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent) {}
    func mouseClickView(_ mouseClickView: MouseClickView, rightMouseDownEvent: NSEvent) {}
    func mouseClickView(_ mouseClickView: MouseClickView, otherMouseDownEvent: NSEvent) {}

}

final class MouseClickView: NSView {

    weak var delegate: MouseClickViewDelegate?

    private func repostMultiClickEventIfNeeded(_ event: NSEvent) -> Bool {
        // don't let more-than-doubleclicks get in
        guard event.clickCount > 2,
            let newEvent = NSEvent.mouseEvent(with: event.type,
                                              location: event.locationInWindow,
                                              modifierFlags: event.modifierFlags,
                                              timestamp: event.timestamp,
                                              windowNumber: event.windowNumber,
                                              context: nil,
                                              eventNumber: event.eventNumber,
                                              clickCount: 1,
                                              pressure: event.pressure),
            let window = self.window
        else { return false }

        // break the growing clickCount event cycle by sending a new 1-click event to the window
        window.postEvent(newEvent, atStart: true)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        let coordinateInWindow = event.locationInWindow
        let coordinateInView = self.convert(coordinateInWindow, from: nil)
        
        if !self.bounds.contains(coordinateInView) {
            return
        }
        
        guard !repostMultiClickEventIfNeeded(event) else { return }

        super.mouseDown(with: event)
        delegate?.mouseClickView(self, mouseDownEvent: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        delegate?.mouseClickView(self, mouseUpEvent: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)

        delegate?.mouseClickView(self, rightMouseDownEvent: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard !repostMultiClickEventIfNeeded(event) else { return }

        super.otherMouseDown(with: event)

        delegate?.mouseClickView(self, otherMouseDownEvent: event)
    }

}
