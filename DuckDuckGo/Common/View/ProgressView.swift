//
//  ProgressView.swift
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

@IBDesignable
final class ProgressView: NSView, CAAnimationDelegate {

    private struct Constants {
        static let gradientAnimationKey = "animateGradient"
        static let progressAnimationKey = "animateProgress"
        static let fadeOutAnimationKey = "animateFadeOut"

        static let max = 1.0

        static let animationDuration: TimeInterval = 0.4
        static let hideAnimationDuration: TimeInterval = 0.2
        static let gradientAnimationDuration: TimeInterval = 0.4

        // Progress steps – Progress Value : Estimated Loading time
        static let milestones: KeyValuePairs<Double, CFTimeInterval> = [
            0.25: 0.0,
            0.40: 3.0,
            0.65: 15.0,
            0.80: 5.0,
            0.85: 3.0,
            1.00: 2.5
        ]

        static let initialValue = milestones[0].key
    }

    private var progressLayer = CAGradientLayer()
    private var progressMask = CALayer()

    private var startTime: CFTimeInterval = 0.0

    private var lastKnownBounds: CGRect = .zero
    private var targetProgress: Double = 0.0
    private var targetTime: CFTimeInterval = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureLayers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configureLayers()
    }

    private func configureLayers() {
        self.wantsLayer = true
        layer!.backgroundColor = NSColor.clear.cgColor

        var progressFrame = bounds
        progressFrame.size.width = 0

        progressMask.anchorPoint = .zero
        progressMask.frame = progressFrame
        lastKnownBounds = progressFrame
        progressMask.backgroundColor = NSColor.white.cgColor

        progressLayer.frame = bounds
        progressLayer.anchorPoint = .zero
        progressLayer.mask = progressMask

        progressLayer.locations = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3]
        progressLayer.startPoint = CGPoint(x: 0, y: 0.5)
        progressLayer.endPoint = CGPoint(x: 1, y: 0.5)

        var colors = [CGColor]()
        for _ in 0...6 {
            colors.append(NSColor.progressBarGradientDarkColor.cgColor)
            colors.append(NSColor.progressBarGradientLightColor.cgColor)
        }

        progressLayer.colors = colors

        layer!.insertSublayer(progressLayer, at: 0)
    }

    func show(progress: Double? = nil, startTime: CFTimeInterval? = nil) {
        let progress = progress.map { max($0, Constants.initialValue) } ?? Constants.initialValue
        self.startTime = startTime ?? CACurrentMediaTime()

        progressMask.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressMask.bounds = calculateProgressMaskRect(for: progress)
        progressMask.opacity = 1
        CATransaction.commit()
        CATransaction.flush()

        startGradientAnimation()

        let nextStep = self.nextStep(for: progress)
        increaseProgress(to: nextStep.progress, animationDuration: nextStep.estimate)
    }

    func increaseProgress(to progress: Double) {
        self.increaseProgress(to: progress, animationDuration: Constants.animationDuration)
    }

    private func increaseProgress(to progress: Double, animationDuration: TimeInterval? = nil) {
        // Workaround for the issue, when iOS removes all animations automatically (e.g. when putting app to the background)
        startGradientAnimation()
        updateProgressMask(to: progress, animationDuration: animationDuration)
    }

    func finishAndHide() {
        guard progressMask.opacity > 0
                && progressMask.animation(forKey: Constants.fadeOutAnimationKey) == nil
        else { return }

        increaseProgress(to: Constants.max, animationDuration: Constants.hideAnimationDuration)
    }

    private func calculateProgressMaskRect(for progress: Double) -> CGRect {
        guard progress < Constants.max else {
            return bounds
        }
        var progressRect = bounds
        progressRect.size.width *= CGFloat(progress) * 0.5
        return progressRect
    }

    private func calculateVisibleProgress(from progressRect: CGRect, parentBounds: CGRect?) -> Double {
        guard progressRect.width < bounds.width else {
            return 1.0
        }
        return Double(progressRect.width / (parentBounds ?? self.bounds).width) * 2.0
    }

    // Currently displayed progress
    private func currentProgress(parentBounds: CGRect? = nil) -> Double {
        calculateVisibleProgress(from: progressMask.presentation()?.bounds ?? progressMask.bounds, parentBounds: parentBounds)
    }

    private func updateProgressMask(to progressValue: Double, animationDuration: TimeInterval?) {
        guard progressMask.animation(forKey: Constants.fadeOutAnimationKey) == nil else { return }

        let actualProgress = self.currentProgress()

        if progressMask.animation(forKey: Constants.progressAnimationKey) != nil {
            progressMask.removeAnimation(forKey: Constants.progressAnimationKey)
        }

        guard progressValue > actualProgress else {
            // proceed to next fake step or hide
            self.progressAnimationDidStop(finished: true)
            return
        }

        self.targetProgress = progressValue
        self.targetTime = CACurrentMediaTime() + (animationDuration ?? 0)

        let progressFrame = calculateProgressMaskRect(for: progressValue)
        if let animationDuration = animationDuration, animationDuration > 0.05 {
            let animation = CABasicAnimation(keyPath: "bounds")
            animation.duration = animationDuration
            animation.fromValue = calculateProgressMaskRect(for: actualProgress)
            animation.toValue = progressFrame
            animation.isRemovedOnCompletion = true
            animation.delegate = self
            progressMask.add(animation, forKey: Constants.progressAnimationKey)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }

        progressMask.bounds = progressFrame

        if (animationDuration ?? 0) > 0 {
            CATransaction.commit()
        } else {
            self.progressAnimationDidStop(finished: true)
        }
    }

    private func nextStep(for currentProgress: Double) -> (progress: Double, estimate: CFTimeInterval) {
        let actualElapsedTime = CACurrentMediaTime() - self.startTime
        var estimatedElapsedTime: CFTimeInterval = 0.0
        var nextEstimate: CFTimeInterval = 0.0
        var nextStep = 0.0

        for (idx, step) in Constants.milestones.enumerated() {
            if currentProgress >= step.key {
                estimatedElapsedTime += step.value
            } else {
                // take percentage of estimated time for the current step based of (actual / estimated) progress difference
                let prevStep = Constants.milestones[safe: idx - 1]?.key ?? 0.0
                let percentagePassed = 1.0 - (step.key - currentProgress) / (step.key - prevStep)
                let passedTime = percentagePassed * step.value
                estimatedElapsedTime += passedTime

                nextStep = step.key
                nextEstimate = step.value - passedTime
                break
            }
        }
        let multiplier = estimatedElapsedTime > 0 ? min(10.0, max(0.1, actualElapsedTime / estimatedElapsedTime)) : 1.0

        return (nextStep, max(multiplier * nextEstimate, Constants.animationDuration))
    }

    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        self.progressAnimationDidStop(finished: finished)
    }

    private func progressAnimationDidStop(finished: Bool) {
        let currentProgress = self.currentProgress()
        if currentProgress >= Constants.max {
            hide(animated: true)

        } else if finished {
            let nextStep = self.nextStep(for: currentProgress)
            guard nextStep.estimate > 0 else { return }
            increaseProgress(to: nextStep.progress, animationDuration: nextStep.estimate)
        }
    }

    override func layout() {
        super.layout()

        progressLayer.frame = bounds
        let currentProgress = self.currentProgress(parentBounds: lastKnownBounds)
        progressMask.frame = calculateProgressMaskRect(for: currentProgress)
        progressMask.removeAnimation(forKey: Constants.progressAnimationKey)

        if targetProgress > currentProgress {
            self.increaseProgress(to: targetProgress, animationDuration: min(0, targetTime - CACurrentMediaTime()))
        }

        lastKnownBounds = bounds
    }

    private func startGradientAnimation() {
        guard progressLayer.animation(forKey: Constants.gradientAnimationKey) == nil else { return }

        let animation = CABasicAnimation(keyPath: "locations")
        animation.toValue = [-0.2, -0.1, 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1]
        animation.duration = Constants.gradientAnimationDuration
        animation.repeatCount = .greatestFiniteMagnitude
        progressLayer.add(animation, forKey: Constants.gradientAnimationKey)
    }

    private func stopGradientAnimation() {
        progressLayer.removeAnimation(forKey: Constants.gradientAnimationKey)
    }

    func hide(animated: Bool = false) {
        if animated {
            CATransaction.begin()
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.duration = Constants.hideAnimationDuration
            progressMask.add(animation, forKey: Constants.fadeOutAnimationKey)
            CATransaction.setCompletionBlock(stopGradientAnimation)
            CATransaction.commit()
        } else {
            progressMask.removeAllAnimations()
            stopGradientAnimation()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressMask.opacity = 0
        CATransaction.commit()
    }

    // MARK: IB
    override func prepareForInterfaceBuilder() {
        layer!.backgroundColor = NSColor.progressBarGradientDarkColor.cgColor
    }

}
