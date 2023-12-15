//
//  NSScreenExtension.swift
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

extension NSScreen {

    static let fallbackHeadlessScreenFrame = NSRect(x: 0, y: 100, width: 1280, height: 900)

    static var dockScreen: NSScreen? {
        screens.min(by: { ($0.frame.height - $0.visibleFrame.height) > ($1.frame.height - $1.visibleFrame.height) })
    }

    static let defaultBackingScaleFactor: CGFloat = 2

    static var maxBackingScaleFactor: CGFloat {
        screens.map(\.backingScaleFactor).max() ?? defaultBackingScaleFactor
    }

    func convert(_ point: NSPoint) -> NSPoint {
        return NSPoint(x: point.x - self.frame.origin.x,
                       y: point.y - self.frame.origin.y)
    }

    func convert(_ rect: NSRect) -> NSRect {
        return NSRect(origin: self.convert(rect.origin), size: rect.size)
    }

}
