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
import Combine

@objc protocol MouseOverViewDelegate: AnyObject {

    @objc optional func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool)
    @objc optional func mouseOverViewIsMoving(_ mouseOverView: MouseOverView)

    @objc optional func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent)
    @objc optional func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent)
    @objc optional func mouseClickView(_ mouseClickView: MouseClickView, rightMouseDownEvent: NSEvent)
    @objc optional func mouseClickView(_ mouseClickView: MouseClickView, otherMouseDownEvent: NSEvent)

}
typealias MouseClickViewDelegate = MouseOverViewDelegate

typealias MouseClickView = MouseOverView
@objc(MouseClickView) final private class _MouseClickView: MouseOverView {}

/// @IBInspectable View with customizable background, mouse-over, mouse-down colors and corner radius.
/// Passes mouse events to its @IBOutlet delegate and/or a default @IBAction set using `sendActionOn:`.
/// Can be used without background only for handling clicks/hover events or only for displaying background without actions.
/// All the magic is happening in `HoverTrackingArea` unifying the behaviour for both MouseOverView and MouseOverButton.
internal class MouseOverView: NSControl, Hoverable {

    @IBOutlet weak var delegate: MouseOverViewDelegate?

    @IBInspectable dynamic var mouseOverColor: NSColor?
    @IBInspectable dynamic var backgroundColor: NSColor?

    @IBInspectable dynamic var cornerRadius: CGFloat = 0.0
    @IBInspectable dynamic var backgroundInset: NSPoint = .zero
    @IBInspectable dynamic var mouseDownColor: NSColor?

    @IBInspectable var clickThrough: Bool = false

    var isMouseOver = false {
        didSet {
            delegate?.mouseOverView?(self, isMouseOver: isMouseOver)
            if isMouseDown {
                isMouseDown = false
            }
        }
    }

    @objc dynamic var isMouseDown: Bool = false

    override class var cellClass: AnyClass? {
        get { nil }
        set { }
    }

    override var cell: NSCell? {
        get { nil }
        set { }
    }

    private var eventTypeMask: NSEvent.EventTypeMask = .leftMouseUp

    override init(frame: NSRect) {
        super.init(frame: frame)

        isEnabled = true
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        isEnabled = true
        clipsToBounds = true
    }

    @discardableResult
    override func sendAction(on mask: NSEvent.EventTypeMask) -> Int {
        self.eventTypeMask = mask
        return Int(truncatingIfNeeded: mask.rawValue)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !clickThrough else { return nil }
        return super.hitTest(point)
    }

    func backgroundLayer(createIfNeeded: Bool) -> CALayer? {
        guard layer == nil || createIfNeeded else { return self.layer }
        self.wantsLayer = true
        assert(self.layer != nil)

        return layer
    }

    private var hoverTrackingArea: HoverTrackingArea? {
        trackingAreas.lazy.compactMap { $0 as? HoverTrackingArea }.first
    }

    override func updateLayer() {
        hoverTrackingArea?.updateLayer()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        HoverTrackingArea.updateTrackingAreas(in: self)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        delegate?.mouseOverViewIsMoving?(self)

        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isMouseLocationInsideBounds(event.locationInWindow) else { return }

        isMouseDown = true
        super.mouseDown(with: event)

        delegate?.mouseClickView?(self, mouseDownEvent: event)
        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isMouseDown {
            isMouseDown = false
        }

        super.mouseUp(with: event)

        delegate?.mouseClickView?(self, mouseUpEvent: event)
        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)

        delegate?.mouseClickView?(self, rightMouseDownEvent: event)
        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)

        delegate?.mouseClickView?(self, otherMouseDownEvent: event)
        if eventTypeMask.contains(.init(type: event.type)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

}
