//
//  CircularProgressView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class CircularProgressView: NSView {

    private let progressLayer = CAShapeLayer()

    @IBInspectable var lineWidth: CGFloat = 3.0 {
        didSet {
            progressLayer.lineWidth = lineWidth
        }
    }
    @IBInspectable var fillColor: NSColor = .clear {
        didSet {
            progressLayer.fillColor = fillColor.cgColor
        }
    }
    @IBInspectable var strokeColor: NSColor = .controlAccentColor {
        didSet {
            progressLayer.strokeColor = strokeColor.cgColor
        }
    }

    var progress: Double? = nil {
        didSet {
            animateProgressLayer()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configureLayers()
    }

    private func configureLayers() {
        self.wantsLayer = true
        self.layer!.backgroundColor = NSColor.clear.cgColor

        progressLayer.autoresizingMask = [.layerHeightSizable, .layerWidthSizable]
        progressLayer.path = self.progressLayerPath()
        progressLayer.lineWidth = self.lineWidth

        self.layer!.addSublayer(progressLayer)
        self.updateLayer()
    }

    override func updateLayer() {
        progressLayer.frame = self.layer!.bounds
        progressLayer.fillColor = self.fillColor.cgColor
        progressLayer.strokeColor = self.strokeColor.cgColor
    }

    private func progressLayerPath() -> CGPath {
        let bounds = self.layer!.bounds
        let radius = abs(min(bounds.width, bounds.height) * 0.5 - lineWidth)
        let rect = NSRect(x: bounds.width * 0.5 - radius, y: bounds.height * 0.5 - radius, width: radius * 2, height: radius * 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        return path.cgPath
    }

    private func animateProgressLayer() {
        progressLayer.removeAllAnimations()
        guard let progress = self.progress else {
            self.progressLayer.isHidden = true
            return
        }
        self.progressLayer.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            let animation = CABasicAnimation(keyPath: "strokeStart")
            let oldValue = self.progressLayer.strokeStart
            self.progressLayer.strokeStart = (0...1.0).contains(progress) ? 1.0 - CGFloat(progress) : 1.0
            animation.fromValue = oldValue
            self.progressLayer.add(animation, forKey: "strokeStart")
        }
    }

}
