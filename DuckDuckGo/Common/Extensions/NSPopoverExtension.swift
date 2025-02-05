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
import Combine
import os.log

extension NSPopover {

    static let defaultMainWindowMargin = 6.0

    /// maximum margin from window edge
    @objc var mainWindowMargin: CGFloat {
        Self.defaultMainWindowMargin
    }

    private static let shouldHideAnchorKey = Data(base64Encoded: "c2hvdWxkSGlkZUFuY2hvcg==")!.utf8String()! // shouldHideAnchor
    var shouldHideAnchor: Bool {
        get {
            value(forKey: Self.shouldHideAnchorKey) as? Bool ?? false
        }
        set {
            setValue(newValue, forKey: Self.shouldHideAnchorKey)
        }
    }

    /// temporary value used to get popover‘s owner window while it‘s not yet set
    @TaskLocal
    static var mainWindow: NSWindow?

    var mainWindow: NSWindow? {
        self.contentViewController?.view.window?.parent ?? Self.mainWindow
    }

    private static let positioningViewKey = UnsafeRawPointer(bitPattern: "positioningViewKey".hashValue)!
    private final class WeakPositioningViewRef: NSObject {
        weak var view: NSView?
        init(_ view: NSView? = nil) {
            self.view = view
        }
    }
    @nonobjc var positioningView: NSView? {
        get {
            (objc_getAssociatedObject(self, Self.positioningViewKey) as? WeakPositioningViewRef)?.view
        }
        set {
            objc_setAssociatedObject(self, Self.positioningViewKey, newValue.map { WeakPositioningViewRef($0) }, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// prefferred bounding box for the popover positioning
    @objc var boundingFrame: NSRect {
        guard let mainWindow else { return .infinite }

        return mainWindow.frame.insetBy(dx: mainWindowMargin, dy: 0)
            .intersection(mainWindow.screen?.visibleFrame ?? .infinite)
    }

    @objc func adjustFrame(_ frame: NSRect) -> NSRect {
        var frame = frame
        let boundingFrame = self.boundingFrame
        if !boundingFrame.isInfinite, boundingFrame.width > frame.width {
            frame.origin.x = min(max(frame.minX, boundingFrame.minX), boundingFrame.maxX - frame.width)
        }
        return frame
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

        Self.$mainWindow.withValue(positioningView.window) {
            self.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
        }
    }

    /// Shows the popover below the specified view with the popover's pin positioned in the middle of the view
    func show(positionedBelow view: NSView) {
        self.show(positionedBelow: view.bounds, in: view)
    }

    func show(positionedAsSubmenuAgainst positioningView: NSView) {
        assert(!positioningView.isHidden && positioningView.alphaValue > 0)
        _=Self.swizzleCurrentFrameOnScreenOnce

        let positioningRect = NSRect(x: 0, y: positioningView.bounds.midY - 1, width: positioningView.bounds.width, height: 2)
        Self.$mainWindow.withValue(positioningView.window) {
            self.show(relativeTo: positioningRect, of: positioningView, preferredEdge: .maxX)
        }
    }

    static let currentFrameOnScreenWithContentSizeSelector = NSSelectorFromString("_currentFrameOnScreenWithContentSize:outAnchorEdge:")

    private static let swizzleCurrentFrameOnScreenOnce: () = {
        guard let originalMethod = class_getInstanceMethod(NSPopover.self, currentFrameOnScreenWithContentSizeSelector),
              let swizzledMethod = class_getInstanceMethod(NSPopover.self, #selector(currentFrameOnScreenWithContentSize)) else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    // place popover inside bounds of its owner Main Window
    @objc(swizzled_currentFrameOnScreenWithContentSize:outAnchorEdge:)
    private dynamic func currentFrameOnScreenWithContentSize(size: NSSize, outAnchorEdge: UnsafeRawPointer?) -> NSRect {
        self.adjustFrame(currentFrameOnScreenWithContentSize(size: size, outAnchorEdge: outAnchorEdge))
    }

    // prevent exception if private API keys go missing
    open override func setValue(_ value: Any?, forUndefinedKey key: String) {
        assertionFailure("setValueForUndefinedKey: \(key)")
    }
    open override func value(forUndefinedKey key: String) -> Any? {
        assertionFailure("valueForUndefinedKey: \(key)")
        return nil
    }

    static let swizzleShowRelativeToRectOnce: () = {
        guard let originalMethod = class_getInstanceMethod(NSPopover.self, #selector(show(relativeTo:of:preferredEdge:))),
              let swizzledMethod = class_getInstanceMethod(NSPopover.self, #selector(swizzled_show(relativeTo:of:preferredEdge:))) else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    // ignore popovers shown from a view not in view hierarchy
    // https://app.asana.com/0/1201037661562251/1206407295280737/f
    @objc(swizzled_showRelativeToRect:ofView:preferredEdge:)
    private dynamic func swizzled_show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        if positioningView.window == nil {
            var observer: Cancellable?
            observer = positioningView.observe(\.window) { positioningView, _ in
                if positioningView.window != nil {
                    self.swizzled_show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
                    observer?.cancel()
                }
            }
            positioningView.onDeinit {
                observer?.cancel()
            }

            Logger.general.error("trying to present \(self) from \(positioningView) not in view hierarchy")
            return
        }
        self.positioningView = positioningView
        self.swizzled_show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}
