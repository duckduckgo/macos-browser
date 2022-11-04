//
//  NSViewExtension.swift
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
import os.log

extension NSView {

    func setCornerRadius(_ radius: CGFloat) {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = radius
    }

    func addAndLayout(_ subView: NSView) {
        subView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subView)

        subView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        subView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        subView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        subView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    func wrappedInContainer(padding: CGFloat = 0) -> NSView {
        return wrappedInContainer(padding: NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
    }

    func wrappedInContainer(padding: NSEdgeInsets = NSEdgeInsets()) -> NSView {
        self.translatesAutoresizingMaskIntoConstraints = false

        let containerView = NSView(frame: self.frame)
        containerView.addSubview(self)

        self.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top).isActive = true
        self.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: padding.left).isActive = true
        self.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -padding.right).isActive = true
        self.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom).isActive = true

        return containerView
    }

    func makeMeFirstResponder() {
        guard let window = window else {
            os_log("%s: Window not available", type: .error, className)
            return
        }

        window.makeFirstResponder(self)
    }

    func applyDropShadow() {
        wantsLayer = true
        layer?.shadowColor = NSColor.controlShadowColor.cgColor
        layer?.shadowOpacity = 1.0
        layer?.masksToBounds = false
    }

    struct NSLayoutConstraintToAttribute {
        let attribute: NSLayoutConstraint.Attribute
        let multiplier: CGFloat
        let constant: CGFloat

        static func top(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .top, multiplier: multiplier, constant: const)
        }
        static func bottom(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .bottom, multiplier: multiplier, constant: const)
        }
        static func leading(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .leading, multiplier: multiplier, constant: const)
        }
        static func trailing(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .trailing, multiplier: multiplier, constant: const)
        }
        static func width(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .width, multiplier: multiplier, constant: const)
        }
        static func height(multiplier: CGFloat = 1.0, const: CGFloat = 0.0) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .width, multiplier: multiplier, constant: const)
        }

        static func const(multiplier: CGFloat = 1.0, _ const: CGFloat) -> NSLayoutConstraintToAttribute {
            NSLayoutConstraintToAttribute(attribute: .notAnAttribute, multiplier: multiplier, constant: const)
        }
    }

    func addConstraints(to view: NSView?,
                        _ attributes: KeyValuePairs<NSLayoutConstraint.Attribute, NSLayoutConstraintToAttribute>)
    -> [NSLayoutConstraint] {
        attributes.map { fromAttr, toAttr in
            NSLayoutConstraint(
                item: self,
                attribute: fromAttr,
                relatedBy: .equal,
                toItem: toAttr.attribute == .notAnAttribute ? nil : view,
                attribute: toAttr.attribute,
                multiplier: toAttr.multiplier,
                constant: toAttr.constant
            )
        }
    }

    func isMouseLocationInsideBounds(_ point: NSPoint? = nil) -> Bool {
        return mouseLocationInsideBounds(point) != nil
    }

    func withMouseLocationInViewCoordinates<T>(_ point: NSPoint? = nil, convert: (NSPoint) -> T?) -> T? {
        guard let mouseLocation = point ?? window?.mouseLocationOutsideOfEventStream else { return nil }
        let locationInView = self.convert(mouseLocation, from: nil)

        return convert(locationInView)
    }

    func mouseLocationInsideBounds(_ point: NSPoint?) -> NSPoint? {
        withMouseLocationInViewCoordinates(point) { locationInView in
            guard self.visibleRect.contains(locationInView) else { return nil }
            return locationInView
        }
    }
    
    func imageRepresentation() -> NSImage {
        let imageRepresentation = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: imageRepresentation)

        return NSImage(cgImage: imageRepresentation.cgImage!, size: bounds.size)
    }

    // MARK: - Favicon

    func applyFaviconStyle() {
        wantsLayer = true
        layer?.cornerRadius = 3.0
    }

    // MARK: - Appearance updates

    /**
     * Sets current app appearance to the view and subscribes for subsequent updates.
     *
     * This is needed on Catalina for views displayed in popovers that have custom, opaque backgrounds.
     * Presentation in popover overrides view appearance to `.vibrantLight` or `.vibrantDark`, which
     * makes subviews such as `NSTextField` and `NSButton` draw their backgrounds with vibrancy effect,
     * which in turn removes opaque background locally. Calling this method on the top-level view seems
     * to be solving the issue.
     *
     * See [](https://app.asana.com/0/1177771139624306/1202121324275642/f) for an example screenshot.
     */
    func subscribeForAppApperanceUpdates() -> AnyCancellable? {
        if #available(macOS 11.0, *) {
            return nil
        }

        appearance = NSApp.effectiveAppearance

        return NSApp
            .publisher(for: \.effectiveAppearance)
            .map { $0 as NSAppearance? }
            .assign(to: \.appearance, onWeaklyHeld: self)
    }

}
