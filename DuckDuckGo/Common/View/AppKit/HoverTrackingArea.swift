//
//  HoverTrackingArea.swift
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
import Foundation

/// Used in `MouseOverView` and `MouseOverButton` to automatically manage `isMouseOver` state and update layer when needed
final class HoverTrackingArea: NSTrackingArea {

    static func updateTrackingAreas(in view: NSView & Hoverable) {
        if let trackingArea = view.trackingAreas.first(where: { $0 is HoverTrackingArea }) {
            view.removeTrackingArea(trackingArea)
        }
        let trackingArea = HoverTrackingArea(owner: view)
        view.addTrackingArea(trackingArea)

        view.isMouseOver = view.isMouseLocationInsideBounds()
        trackingArea.updateLayer()
    }

    // mouseEntered and mouseExited events will be received by the HoverTrackingArea itself
    override var owner: AnyObject? {
        self
    }

    private weak var view: Hoverable? {
        super.owner as? Hoverable
    }

    private var observers: [NSKeyValueObservation]?

    init(owner: some Hoverable) {
        super.init(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .enabledDuringMouseDrag, .inVisibleRect], owner: owner, userInfo: nil)

        observers = [
            owner.observe(\.backgroundColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.mouseOverColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.mouseDownColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.cornerRadius) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.cornerRadius) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.isMouseDown) { [weak self] _, _ in self?.mouseDownDidChange() },
            owner.observe(\.frame) { [weak self] _, _ in self?.viewFrameDidChange() },
        ]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func layer(createIfNeeded: Bool) -> CALayer? {
        view?.backgroundLayer(createIfNeeded: createIfNeeded)
    }

    func updateLayer() {
        guard let view else { return }

        let color: NSColor?
        if (view as? NSControl)?.isEnabled == false {
            color = .clear
        } else if view.isMouseDown {
            color = view.mouseDownColor ?? view.mouseOverColor ?? view.backgroundColor
        } else if view.isMouseOver {
            color = view.mouseOverColor ?? view.backgroundColor
        } else {
            color = view.backgroundColor
        }

        guard let color, color != .clear else {
            layer(createIfNeeded: false)?.backgroundColor = .clear
            return
        }
        guard let layer = layer(createIfNeeded: true) else { return }

        layer.cornerRadius = view.cornerRadius
        layer.frame = view.bounds.insetBy(dx: view.backgroundInset.x, dy: view.backgroundInset.y)

        NSAppearance.withAppAppearance {
            NSAnimationContext.runAnimationGroup { context in
                if view.isMouseDown || view.isMouseOver {
                    context.duration = 0.0
                }

                layer.backgroundColor = color.cgColor
            }
        }
    }

    @objc func mouseEntered(_ event: NSEvent) {
        view?.isMouseOver = true
        updateLayer()
        view?.mouseEntered(with: event)
    }

    @objc func mouseExited(_ event: NSEvent) {
        view?.isMouseOver = false
        updateLayer()
        view?.mouseExited(with: event)
    }

    private func mouseDownDidChange() {
        guard let view else { return }

        if view.isMouseOver,
           view.window?.isKeyWindow != true || view.isMouseLocationInsideBounds() != true,
           let event = NSApp.currentEvent {

            mouseExited(event)
        } else {
            updateLayer()
        }
    }

    private func viewFrameDidChange() {
        guard let view else { return }
        view.isMouseOver = view.isMouseLocationInsideBounds()
        updateLayer()
    }

}

@objc protocol HoverableProperties {

    @objc dynamic var backgroundColor: NSColor? { get }

    @objc dynamic var mouseOverColor: NSColor? { get }

    @objc dynamic var mouseDownColor: NSColor? { get }

    @objc dynamic var cornerRadius: CGFloat { get }

    @objc dynamic var backgroundInset: NSPoint { get }

    @objc dynamic var isMouseDown: Bool { get }

    var isMouseOver: Bool { get set }

}

protocol Hoverable: NSView, HoverableProperties {

    func backgroundLayer(createIfNeeded: Bool) -> CALayer?

}
