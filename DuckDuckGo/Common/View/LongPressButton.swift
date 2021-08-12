//
//  LongPressButton.swift
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

final class LongPressButton: MouseOverButton {

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = self.menu else {
            super.rightMouseDown(with: event)
            return
        }

        self.isMouseDown = true
        displayMenu(menu)
        self.isMouseDown = false
    }

    private var menuTimer: Timer?

    override func mouseDown(with event: NSEvent) {
        menuTimer?.invalidate()
        menuTimer = nil

        guard let menu = self.menu else {
            super.mouseDown(with: event)
            return
        }

        self.isMouseDown = true

        let timer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.displayMenu(menu)
            guard let event = event.makeMouseUpEvent() else { return }
            // post new event to unblock waiting for nextEvent
            self?.window?.postEvent(event, atStart: true)
        }
        menuTimer = timer
        RunLoop.current.add(timer, forMode: .eventTracking)

        trackMouseEvents(withDelayedMenu: menu, previousEvent: event)

        menuTimer?.invalidate()
        menuTimer = nil

        self.isMouseDown = false
    }

    private func trackMouseEvents(withDelayedMenu menu: NSMenu, previousEvent: NSEvent) {
        while let event = self.window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            switch event.type {
            case .leftMouseDragged:
                // ignore and return if menu was already shown
                guard menuTimer != nil else { return }
                // if on vertical mouse movement show menu instantly; ignore and return on X mouse-out
                guard self.withMouseLocationInViewCoordinates(event.locationInWindow, convert: { locationInView in
                    (self.bounds.minX...self.bounds.maxX).contains(locationInView.x)
                }) == true else { return }
                // should be a real mouse dragged event otherwise wait for next
                guard Int(event.locationInWindow.x) != Int(previousEvent.locationInWindow.x),
                      Int(event.locationInWindow.y) != Int(previousEvent.locationInWindow.y)
                else { break }

                self.displayMenu(menu)
                return

            case .leftMouseUp:
                guard menuTimer != nil,
                      self.isMouseLocationInsideBounds(event.locationInWindow)
                else { return }
                // mouseUp before menu shown means click
                self.sendAction(self.action, to: self.target)
                return

            default:
                assertionFailure("Unexpected event type")
                return
            }
        }
    }

    private func displayMenu(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: self.bounds.height + 4), in: self)
    }

}

private extension NSEvent {
    func makeMouseUpEvent() -> NSEvent? {
        return NSEvent.mouseEvent(with: .leftMouseUp,
                                  location: self.locationInWindow,
                                  modifierFlags: self.modifierFlags,
                                  timestamp: self.timestamp,
                                  windowNumber: self.windowNumber,
                                  context: nil,
                                  eventNumber: self.eventNumber,
                                  clickCount: self.clickCount,
                                  pressure: self.pressure)
    }
}
