//
//  MouseOverButton.swift
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

internal class MouseOverButton: NSButton, Hoverable {

    private var backgroundLayer: CALayer?

    @IBInspectable dynamic var backgroundColor: NSColor?
    @IBInspectable dynamic var mouseOverColor: NSColor?
    @IBInspectable dynamic var mouseDownColor: NSColor?

    @IBInspectable dynamic var cornerRadius: CGFloat = 0
    @IBInspectable dynamic var backgroundInset: NSPoint = .zero

    @IBInspectable var mouseOverTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }

    @IBInspectable var mouseDownTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }

    var normalTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }

    func backgroundLayer(createIfNeeded: Bool) -> CALayer? {
        guard backgroundLayer == nil, createIfNeeded else { return backgroundLayer }

        self.wantsLayer = true
        self.layerUsesCoreImageFilters = true
        guard let layer else {
            assertionFailure("no layer")
            return nil
        }

        layer.backgroundColor = .clear

        let backgroundLayer = CALayer()
        backgroundLayer.masksToBounds = true
        layer.addSublayer(backgroundLayer)
        self.backgroundLayer = backgroundLayer

        return backgroundLayer
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
    }

    override func awakeFromNib() {
        normalTintColor = self.contentTintColor
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        isMouseDown = false
    }

    @Published var isMouseOver = false {
        didSet {
            updateTintColor()
        }
    }

    @objc dynamic var isMouseDown = false {
        didSet {
            updateTintColor()
        }
    }

    func updateTintColor() {
        NSAppearance.withAppAppearance {
            if isMouseDown {
                self.contentTintColor = self.mouseDownTintColor ?? self.normalTintColor
            } else if isMouseOver {
                self.contentTintColor = self.mouseOverTintColor ?? self.normalTintColor
            } else {
                self.contentTintColor = self.normalTintColor
            }
        }
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

    override func mouseDown(with event: NSEvent) {
        isMouseDown = true
        super.mouseDown(with: event)
        isMouseDown = false
    }

}
