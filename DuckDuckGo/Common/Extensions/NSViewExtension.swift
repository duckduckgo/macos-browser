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
import Common
import os.log

extension NSView {

    // Since macOS 14 Sonoma view has clipsToBound == false by default
    func visibleRectClampedToBounds() -> NSRect {
        var visibleRect = self.visibleRect

        guard !clipsToBounds, let superview else { return visibleRect }
        let frame = self.frame
        visibleRect = frame

        if superview.isFlipped != isFlipped {
            visibleRect.origin.y = superview.bounds.height - visibleRect.origin.y - visibleRect.height
        }

        visibleRect = visibleRect.intersection(superview.visibleRect)
        visibleRect.origin.x -= frame.origin.x
        visibleRect.origin.y -= frame.origin.y

        return visibleRect
    }

    func setCornerRadius(_ radius: CGFloat) {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = radius
    }

    func addAndLayout(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        subview.frame = bounds
        subview.autoresizingMask = [.height, .width]
        subview.translatesAutoresizingMaskIntoConstraints = true

        addSubview(subview)
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

    func hidden() -> Self {
        self.isHidden = true
        return self
    }

    var isShown: Bool {
        get { !isHidden }
        set { isHidden = !newValue }
    }

    var isVisible: Bool {
        guard !isHiddenOrHasHiddenAncestor,
              let window, window.isVisible else { return false }
        return true
    }

    func makeMeFirstResponder() {
        guard let window = window else {
            Logger.general.error("\(self.className): Window not available")
            return
        }
        // prevent all text selection on repeated Address Bar activation
        guard window.firstResponder !== (self as? NSControl)?.currentEditor() ?? self else { return }

        window.makeFirstResponder(self)
    }

    func applyDropShadow() {
        wantsLayer = true
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
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
            NSLayoutConstraintToAttribute(attribute: .height, multiplier: multiplier, constant: const)
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

    func mouseLocationInsideBounds(_ point: NSPoint? = nil) -> NSPoint? {
        withMouseLocationInViewCoordinates(point) { locationInView in
            guard self.visibleRectClampedToBounds().contains(locationInView) else { return nil }
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

}
