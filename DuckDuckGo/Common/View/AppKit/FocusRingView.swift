//
//  FocusRingView.swift
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

final class FocusRingView: NSView {

    enum Size {
        static let shadow = 2.5
        static let stroke = 0.5
        static let backgroundRadius = 8.0
    }

    var strokedBackgroundColor = NSColor.addressBarFocusedBackgroundColor
    var unstrokedBackgroundColor = NSColor.addressBarBackgroundColor

    private let shadowLayer = CALayer()
    private let strokeLayer = CALayer()
    private let backgroundLayer = CALayer()

    private var stroke = false

    private var keyWindowCancellable: AnyCancellable?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil else {
            keyWindowCancellable = nil
            return
        }
        wantsLayer = true

        addSublayers()
        keyWindowCancellable = NSApp.publisher(for: \.keyWindow)
            .combineLatest(NSApp.isActivePublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLayer()
        }
    }

    override func layout() {
        super.layout()

        updateLayer()
    }

    func updateView(stroke: Bool) {
        self.stroke = stroke
        self.needsLayout = true
    }

    private func addSublayers() {
        guard shadowLayer.superlayer == nil else { return }

        shadowLayer.opacity = 0
        layer?.addSublayer(shadowLayer)

        strokeLayer.opacity = 0
        layer?.addSublayer(strokeLayer)

        layer?.addSublayer(backgroundLayer)
    }

    override func updateLayer() {
        guard let layer = layer else { return }

        CATransaction.begin()

        let stroke = self.stroke && NSApp.isActive && NSApp.keyWindow === window
        shadowLayer.opacity = stroke ? 0.4 : 0
        strokeLayer.opacity = stroke ? 1.0 : 0

        backgroundLayer.backgroundColor = stroke ?
            strokedBackgroundColor.cgColor : unstrokedBackgroundColor.cgColor

        shadowLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        strokeLayer.backgroundColor = NSColor.controlAccentColor.cgColor

        shadowLayer.frame = layer.bounds
        shadowLayer.cornerRadius = Size.backgroundRadius + Size.shadow + Size.stroke
        strokeLayer.frame = NSRect(x: layer.bounds.origin.x + Size.shadow,
                                   y: layer.bounds.origin.y + Size.shadow,
                                   width: layer.bounds.size.width - 2 * Size.shadow,
                                   height: layer.bounds.size.height - 2 * Size.shadow)
        strokeLayer.cornerRadius = Size.backgroundRadius + Size.stroke
        backgroundLayer.frame = NSRect(x: layer.bounds.origin.x + Size.shadow + Size.stroke,
                                       y: layer.bounds.origin.y + Size.shadow + Size.stroke,
                                       width: layer.bounds.size.width - 2 * (Size.shadow + Size.stroke),
                                       height: layer.bounds.size.height - 2 * (Size.shadow + Size.stroke))
        backgroundLayer.cornerRadius = Size.backgroundRadius

        CATransaction.commit()
    }
    
}
