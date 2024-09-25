//
//  UserColorProviding.swift
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
import Combine
import Foundation

protocol UserColorProviding {
    var colorPublisher: AnyPublisher<NSColor, Never> { get }

    func showColorPanel(with color: NSColor?)
    func closeColorPanel()
}

extension NSColorPanel: UserColorProviding {
    var colorPublisher: AnyPublisher<NSColor, Never> {
        publisher(for: \.color).dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    func showColorPanel(with color: NSColor?) {
        if let color {
            self.color = color
        }

        if !isVisible {
            var frame = self.frame
            frame.origin = NSEvent.mouseLocation
            if let keyWindow = NSApp.keyWindow {
                frame.origin.x = keyWindow.frame.maxX - frame.size.width
            }
            frame.origin.y -= frame.size.height + 40
            setFrame(frame, display: true)
        }

        showsAlpha = false
        orderFront(nil)
    }

    func closeColorPanel() {
        close()
    }
}
