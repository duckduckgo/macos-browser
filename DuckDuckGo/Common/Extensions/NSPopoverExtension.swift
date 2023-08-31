//
//  NSPopoverExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

extension NSPopover {

    static let defaultMainWindowMargin = 6.0
    @objc var mainWindowMargin: CGFloat {
        Self.defaultMainWindowMargin
    }

    /// Shows the popover below the specified rect inside the view bounds with the popover's pin positioned in the middle of the rect
    public func show(positionedBelow positioningRect: NSRect, in positioningView: NSView) {
        assert(!positioningView.isHidden && positioningView.alphaValue > 0)

        // We tap into `_currentFrameOnScreenWithContentSize:outAnchorEdge:` to adjust popover position
        // inside bounds of its owner Main Window.
        // https://app.asana.com/0/1177771139624306/1202217488822824/f
        _=Self.swizzleCurrentFrameOnScreenOnce

        // position popover at the middle of the positioningView
        let positioningRect = NSRect(x: positioningRect.midX - 1, y: positioningRect.origin.y, width: 2, height: positioningRect.height)
        let preferredEdge: NSRectEdge = positioningView.isFlipped ? .maxY : .minY

        self.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    /// Shows the popover below the specified view with the popover's pin positioned in the middle of the view
    func show(positionedBelow view: NSView) {
        self.show(positionedBelow: view.bounds, in: view)
    }

    private static let swizzleCurrentFrameOnScreenOnce: () = {
        guard let originalMethod = class_getInstanceMethod(NSPopover.self, NSSelectorFromString("_currentFrameOnScreenWithContentSize:outAnchorEdge:")),
              let swizzledMethod = class_getInstanceMethod(NSPopover.self, #selector(currentFrameOnScreenWithContentSize)) else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    // place popover inside bounds of its owner Main Window
    @objc(swizzled_currentFrameOnScreenWithContentSize:outAnchorEdge:)
    private dynamic func currentFrameOnScreenWithContentSize(size: NSSize, outAnchorEdge: UnsafeRawPointer?) -> NSRect {
        var frame = self.currentFrameOnScreenWithContentSize(size: size, outAnchorEdge: outAnchorEdge)
        if let mainWindow = self.contentViewController?.view.window?.parent,
           mainWindow.frame.width >= (frame.width + mainWindowMargin * 2) {

            frame.origin.x = min(max(frame.minX, mainWindow.frame.minX + mainWindowMargin), mainWindow.frame.maxX - frame.width - mainWindowMargin)
        }

        return frame
    }

}
