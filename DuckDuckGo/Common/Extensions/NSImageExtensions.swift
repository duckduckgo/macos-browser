//
//  NSImageExtensions.swift
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
import CoreGraphics

extension NSImage {

    func resized(to size: NSSize) -> NSImage? {
        let image = NSImage(size: size)
        let targetRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let currentRect = NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height)

        image.lockFocus()
        let graphicsContext = NSGraphicsContext.current
        graphicsContext?.imageInterpolation = .high
        self.draw(in: targetRect, from: currentRect, operation: .copy, fraction: 1)
        image.unlockFocus()

        return image
    }

    func resizedToFaviconSize() -> NSImage? {
        if size.width > NSSize.faviconSize.width ||
            size.height > NSSize.faviconSize.height {
            return resized(to: .faviconSize)
        }
        return self
    }

    func tinted(with color: NSColor) -> NSImage {
        guard let image = self.copy() as? NSImage else {
            return self
        }

        image.lockFocus()

        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()

        return image
    }

    func ciImage(with size: NSSize?) -> CIImage {
        var rect = NSRect(origin: .zero, size: size ?? self.size)
        return CIImage(cgImage: self.cgImage(forProposedRect: &rect, context: nil, hints: nil)!)
    }

}
