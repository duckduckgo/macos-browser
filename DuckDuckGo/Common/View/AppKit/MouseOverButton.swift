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

@objc protocol MouseOverButtonDelegate: AnyObject {

    @objc optional func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation
    @objc optional func mouseOverButton(_ sender: MouseOverButton, draggingUpdatedWith info: NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation
    @objc optional func mouseOverButton(_ sender: MouseOverButton, draggingEndedWith info: NSDraggingInfo)
    @objc optional func mouseOverButton(_ sender: MouseOverButton, draggingExitedWith info: NSDraggingInfo?)
    @objc optional func mouseOverButton(_ sender: MouseOverButton, performDragOperation info: NSDraggingInfo) -> Bool

}

internal class MouseOverButton: NSButton, Hoverable {

    @IBOutlet weak var delegate: MouseOverButtonDelegate?

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

    @objc dynamic var isMouseOver = false {
        didSet {
            updateTintColor()
        }
    }

    @objc dynamic var isMouseDown = false {
        didSet {
            updateTintColor()
        }
    }

    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        var newMouseOver: Bool?
        var isMouseOver: Bool {
            get {
                newMouseOver ?? self.isMouseOver
            }
            set {
                newMouseOver = newValue
            }
        }
        let operation = delegate?.mouseOverButton?(self, draggingEntered: draggingInfo, isMouseOver: &isMouseOver) ?? .none
        // set isMouseOver if delegate has modified it
        if let newMouseOver, newMouseOver != self.isMouseOver {
            self.isMouseOver = newMouseOver
        }
        return operation
    }

    override func draggingUpdated(_ draggingInfo: any NSDraggingInfo) -> NSDragOperation {
        var newMouseOver: Bool?
        var isMouseOver: Bool {
            get {
                newMouseOver ?? self.isMouseOver
            }
            set {
                newMouseOver = newValue
            }
        }
        let operation = delegate?.mouseOverButton?(self, draggingUpdatedWith: draggingInfo, isMouseOver: &isMouseOver) ?? super.draggingUpdated(draggingInfo)
        // set isMouseOver if delegate has modified it
        if let newMouseOver, newMouseOver != self.isMouseOver {
            self.isMouseOver = newMouseOver
        }
        return operation
    }

    override func performDragOperation(_ draggingInfo: any NSDraggingInfo) -> Bool {
        return delegate?.mouseOverButton?(self, performDragOperation: draggingInfo) ?? false
    }

    override func draggingEnded(_ draggingInfo: any NSDraggingInfo) {
        isMouseOver = false
        delegate?.mouseOverButton?(self, draggingEndedWith: draggingInfo)
    }

    override func draggingExited(_ draggingInfo: NSDraggingInfo?) {
        isMouseOver = false
        delegate?.mouseOverButton?(self, draggingExitedWith: draggingInfo)
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
