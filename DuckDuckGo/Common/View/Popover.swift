//
//  Popover.swift
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

class Popover: NSPopover {

    weak private var associatedButton: NSButton?

    override func close() {
        super.close()

        turnOffButton()
    }

    override func performClose(_ sender: Any?) {
        super.performClose(sender)

        turnOffButton()
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        if let button = positioningView as? NSButton {
            self.associatedButton = button
        }

        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    private func turnOffButton() {
        if associatedButton?.state == .on {
            associatedButton?.state = .off
        }
    }

}
