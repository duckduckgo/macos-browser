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
        for trackingArea in view.trackingAreas where trackingArea is HoverTrackingArea {
            view.removeTrackingArea(trackingArea)
        }
        let trackingArea = HoverTrackingArea(owner: view)
        view.addTrackingArea(trackingArea)

        view.isMouseOver = view.isMouseLocationInsideBounds()
        trackingArea.updateLayer(animated: false)
    }

    // mouseEntered and mouseExited events will be received by the HoverTrackingArea itself
    override var owner: AnyObject? {
        self
    }

    private weak var view: Hoverable? {
        super.owner as? Hoverable
    }

    private var currentBackgroundColor: NSColor? {
        guard let view else { return nil }

        if (view as? NSControl)?.isEnabled == false {
            return nil
        } else if view.isMouseDown {
            return view.mouseDownColor ?? view.mouseOverColor ?? view.backgroundColor
        } else if view.isMouseOver {
            return view.mouseOverColor ?? view.backgroundColor
        } else {
            return view.backgroundColor
        }
    }

    private var observers: [NSKeyValueObservation]?

    init(owner: some Hoverable) {
        super.init(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .enabledDuringMouseDrag, .inVisibleRect], owner: owner, userInfo: nil)

        observers = [
            owner.observe(\.backgroundColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.mouseOverColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.mouseDownColor) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.cornerRadius) { [weak self] _, _ in self?.updateLayer() },
            owner.observe(\.backgroundInset) { [weak self] _, _ in self?.updateLayer() },
            (owner as? NSControl)?.observe(\.isEnabled) { [weak self] _, _ in self?.updateLayer(animated: false) },
            owner.observe(\.isMouseDown) { [weak self] _, _ in self?.mouseDownDidChange() },
            owner.observe(\.window) { [weak self] _, _ in self?.viewWindowDidChange() },
        ].compactMap { $0 }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func layer(createIfNeeded: Bool) -> CALayer? {
        view?.backgroundLayer(createIfNeeded: createIfNeeded)
    }

    func updateLayer(animated: Bool = true) {
        let color = currentBackgroundColor ?? .clear
        guard let view, let layer = layer(createIfNeeded: color != .clear) else { return }

        layer.cornerRadius = view.cornerRadius
        layer.frame = view.bounds.insetBy(dx: view.backgroundInset.x, dy: view.backgroundInset.y)

        NSAppearance.withAppAppearance {
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                // mousedown/over state should be applied instantly
                // animation should be also disabled on view reuse
                if !animated || view.isMouseDown || view.isMouseOver {
                    layer.removeAllAnimations()
                    context.duration = 0.0
                }

                layer.backgroundColor = color.cgColor
            }
        }
    }

    @objc func mouseEntered(_ event: NSEvent) {
        view?.isMouseOver = true
        updateLayer(animated: false)
        view?.mouseEntered(with: event)
    }

    @objc func mouseExited(_ event: NSEvent) {
        view?.isMouseOver = false
        updateLayer(animated: true)
        view?.mouseExited(with: event)
    }

    private func mouseDownDidChange() {
        guard let view else { return }

        if view.isMouseOver,
           view.window?.isKeyWindow != true || view.isMouseLocationInsideBounds() != true,
           let event = NSApp.currentEvent {

            mouseExited(event)
        } else {
            updateLayer(animated: false)
        }
    }

    private func viewWindowDidChange() {
        guard let view else { return }
        view.isMouseOver = view.isMouseLocationInsideBounds()
        updateLayer(animated: false)
    }

}

@objc protocol HoverableProperties {

    @objc dynamic var backgroundColor: NSColor? { get }

    @objc dynamic var mouseOverColor: NSColor? { get }

    @objc dynamic var mouseDownColor: NSColor? { get }

    @objc dynamic var cornerRadius: CGFloat { get }

    @objc dynamic var backgroundInset: NSPoint { get }

    @objc dynamic var isMouseDown: Bool { get }

}

protocol Hoverable: NSView, HoverableProperties {

    var isMouseOver: Bool { get set }

    func backgroundLayer(createIfNeeded: Bool) -> CALayer?

}
