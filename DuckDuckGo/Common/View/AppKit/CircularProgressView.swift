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
    private var backgroundLayer = CAShapeLayer()

    @IBInspectable var lineWidth: CGFloat = 3.0 {
        didSet {
            progressLayer.lineWidth = lineWidth
        }
    }
    @IBInspectable var backgroundLineWidth: CGFloat = 2.0 {
        didSet {
            backgroundLayer.lineWidth = lineWidth
        }
    }

    @IBInspectable var strokeColor: NSColor = .controlAccentColor {
        didSet {
            progressLayer.strokeColor = strokeColor.cgColor
        }
    }
    @IBInspectable var backgroundStrokeColor: NSColor = .buttonMouseOverColor {
        didSet {
            backgroundLayer.fillColor = backgroundStrokeColor.cgColor
        }
    }

    var indeterminateProgressValue: CGFloat = 0.2
    var animationDuration: TimeInterval = 0.5
    var rotationDuration: TimeInterval = 1.5

    var progress: Double? {
        didSet {
            updateProgress()
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

        let radius = min(self.bounds.width, self.bounds.height) * 0.5 - max(lineWidth, backgroundLineWidth)

        backgroundLayer.configureCircle(radius: radius, lineWidth: backgroundLineWidth)
        backgroundLayer.strokeStart = 1.0
        backgroundLayer.strokeEnd = 1.0
        self.layer!.addSublayer(backgroundLayer)

        progressLayer.configureCircle(radius: radius, lineWidth: lineWidth)
        progressLayer.strokeStart = 1.0
        progressLayer.strokeEnd = 1.0
        self.layer!.addSublayer(progressLayer)

        self.updateLayer()
    }

    override func updateLayer() {
        let bounds = self.layer!.bounds
        progressLayer.frame = CGRect(x: (bounds.width - progressLayer.bounds.width) * 0.5,
                                     y: (bounds.height - progressLayer.bounds.height) * 0.5,
                                     width: progressLayer.bounds.width,
                                     height: progressLayer.bounds.height)
        backgroundLayer.frame = CGRect(x: (bounds.width - backgroundLayer.bounds.width) * 0.5,
                                       y: (bounds.height - backgroundLayer.bounds.height) * 0.5,
                                       width: backgroundLayer.bounds.width,
                                       height: backgroundLayer.bounds.height)
        progressLayer.strokeColor = self.strokeColor.cgColor
        backgroundLayer.strokeColor = self.backgroundStrokeColor.cgColor
    }

    private enum AnimationKeys {
        static let strokeStart = "strokeStart"
        static let strokeEnd = "strokeEnd"
        static let rotation = "rotation"
        static let stopRotation = "transform"
    }

    override func prepareForReuse() {
        progress = nil
    }

    private func updateProgress() {
        let isBackgroundAnimating = backgroundLayer.animation(forKey: AnimationKeys.strokeStart) != nil
            || backgroundLayer.animation(forKey: AnimationKeys.strokeEnd) != nil
        let isProgressShown = (backgroundLayer.strokeStart == 0.0 && backgroundLayer.strokeEnd != 0.0)

        guard self.window != nil else {
            backgroundLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()

            backgroundLayer.strokeEnd = 1.0
            backgroundLayer.strokeStart = (progress == nil) ? 1.0 : 0.0

            progressLayer.strokeEnd = 1.0
            progressLayer.strokeStart = (progress == nil)
                ? 1.0
                : (progress! > 0) ? (1.0 - CGFloat(progress!)) : self.indeterminateProgressValue
            return
        }
        guard !isBackgroundAnimating else {
            // will call updateProgress on animation completion
            return
        }

        switch (isProgressShown, (progress != nil)) {
        case (false, true):
            showProgressAnimated()
        case (true, false):
            hideProgressAnimated()
        case (true, true):
            updateProgressAnimated()
        case (false, false):
            return
        }
    }

    private func showProgressAnimated() {
        backgroundLayer.removeAllAnimations()
        progressLayer.removeAllAnimations()

        self.backgroundLayer.strokeEnd = 1.0
        self.progressLayer.strokeStart = 1.0
        self.progressLayer.strokeEnd = 1.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = self.animationDuration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)

            let animation = CABasicAnimation(keyPath: (\CAShapeLayer.strokeStart)._kvcKeyPathString!)
            self.backgroundLayer.strokeStart = 0.0
            animation.fromValue = 1.0
            animation.isRemovedOnCompletion = true
            self.backgroundLayer.add(animation, forKey: AnimationKeys.strokeStart)

        } completionHandler: { [weak self] in
            self?.updateProgress()
        }
    }

    private func startRotation() {
        guard progressLayer.animation(forKey: AnimationKeys.rotation) == nil else { return }

        let currentRotation = (progressLayer.presentation() ?? progressLayer).value(forKeyPath: "transform.rotation") as? CGFloat ?? 0.0
        progressLayer.removeAnimation(forKey: AnimationKeys.stopRotation)

        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = currentRotation
        rotation.toValue = currentRotation - CGFloat.pi * 2
        rotation.duration = self.rotationDuration
        rotation.repeatCount = .greatestFiniteMagnitude

        self.progressLayer.add(rotation, forKey: AnimationKeys.rotation)
    }

    private func stopRotation() {
        guard progressLayer.animation(forKey: AnimationKeys.rotation) != nil,
              progressLayer.animation(forKey: AnimationKeys.stopRotation) == nil
        else { return }

        let currentRotation = progressLayer.presentation()?.value(forKeyPath: "transform.rotation") as? CGFloat ?? 0.0
        self.progressLayer.removeAnimation(forKey: AnimationKeys.rotation)

        let stopRotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        stopRotationAnimation.fromValue = currentRotation
        stopRotationAnimation.toValue = -CGFloat.pi * 2
        stopRotationAnimation.isRemovedOnCompletion = true

        self.progressLayer.add(stopRotationAnimation, forKey: AnimationKeys.stopRotation)
    }

    private func updateProgressAnimated() {
        guard let progress = progress else {
            assertionFailure("Unexpected flow")
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = self.animationDuration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .linear)

            let animation = CABasicAnimation(keyPath: "strokeStart")
            let currentStrokeStart = progressLayer.strokeStart
            self.progressLayer.removeAnimation(forKey: AnimationKeys.strokeStart)
            let newStrokeStart = 1.0 - (progress >= 0.0
                                            ? CGFloat(progress)
                                            : max(self.indeterminateProgressValue, min(0.9, 1.0 - currentStrokeStart)))
            self.progressLayer.strokeStart = newStrokeStart
            animation.fromValue = currentStrokeStart
            animation.isRemovedOnCompletion = true
            self.progressLayer.add(animation, forKey: AnimationKeys.strokeStart)

            self.stopRotation()

        } completionHandler: { [weak self] in
            guard let self = self, let progress = self.progress else { return }
            self.progressLayer.setValue(0.0, forKeyPath: "transform.rotation")
            if progress < 0.0 {
                self.startRotation()
            }
        }
    }

    private func hideProgressAnimated() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = self.animationDuration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let backgroundAnimation = CABasicAnimation(keyPath: "strokeEnd")
            self.backgroundLayer.strokeEnd = 0.0
            backgroundAnimation.fromValue = 1.0
            backgroundAnimation.isRemovedOnCompletion = true
            self.backgroundLayer.add(backgroundAnimation, forKey: AnimationKeys.strokeEnd)

            let progressEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
            self.progressLayer.strokeEnd = 0.0
            progressEndAnimation.fromValue = 1.0
            progressEndAnimation.isRemovedOnCompletion = true
            self.progressLayer.add(progressEndAnimation, forKey: AnimationKeys.strokeEnd)

            let progressAnimation = CABasicAnimation(keyPath: "strokeStart")
            let currentStrokeStart = (progressLayer.presentation() ?? progressLayer).value(forKey: "strokeStart") as? CGFloat ?? 0
            self.progressLayer.removeAnimation(forKey: AnimationKeys.strokeStart)
            self.progressLayer.strokeStart = 0.0
            progressAnimation.fromValue = currentStrokeStart
            progressAnimation.isRemovedOnCompletion = true
            self.progressLayer.add(progressAnimation, forKey: AnimationKeys.strokeStart)

            self.stopRotation()

        } completionHandler: { [weak self] in
            self?.updateProgress()
        }
    }

}

private extension CAShapeLayer {

    func configureCircle(radius: CGFloat, lineWidth: CGFloat) {
        self.bounds = CGRect(x: 0, y: 0, width: (radius + lineWidth) * 2, height: (radius + lineWidth) * 2)

        let rect = NSRect(x: lineWidth, y: lineWidth, width: radius * 2, height: radius * 2)
        self.path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath

        self.lineWidth = lineWidth
        self.fillColor = NSColor.clear.cgColor
    }

}
