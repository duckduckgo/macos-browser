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
import SwiftUI

final class CircularProgressView: NSView {

    private enum Constants {
        static let indeterminateProgressValue: CGFloat = 0.2
        static let animationDuration: TimeInterval = 0.5
        static let rotationDuration: TimeInterval = 1.5
    }

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
    @IBInspectable var backgroundStrokeColor: NSColor = .buttonMouseOver {
        didSet {
            backgroundLayer.fillColor = backgroundStrokeColor.cgColor
        }
    }
    var animationMultiplier: CGFloat = 1.0

    private(set) var progress: Double?

    private var isBackgroundAnimating: Bool {
        [#keyPath(CAShapeLayer.strokeStart), #keyPath(CAShapeLayer.strokeEnd)].contains {
            backgroundLayer.animation(forKey: $0) != nil
        }
    }

    private var isProgressAnimating: Bool {
        [
            AnimationKeys.rotation,
            AnimationKeys.stopRotation,
            #keyPath(CAShapeLayer.strokeStart),
            #keyPath(CAShapeLayer.strokeStart)
        ].contains {
            progressLayer.animation(forKey: $0) != nil
        }
    }

    init(frame: CGRect = .zero, lineWidth: CGFloat? = nil, backgroundLineWidth: CGFloat? = nil, strokeColor: NSColor? = nil, backgroundStrokeColor: NSColor? = nil, progress: Double? = nil, animationMultiplier: CGFloat = 1.0) {
        super.init(frame: frame)

        if let lineWidth {
            self.lineWidth = lineWidth
        }
        if let backgroundLineWidth {
            self.backgroundLineWidth = backgroundLineWidth
        }
        if let strokeColor {
            self.strokeColor = strokeColor
        }
        if let backgroundStrokeColor {
            self.backgroundStrokeColor = backgroundStrokeColor
        }
        self.progress = progress
        self.animationMultiplier = animationMultiplier

        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configureLayers()
    }

    private func configureLayers() {
        self.wantsLayer = true
        self.layer!.backgroundColor = NSColor.clear.cgColor

        backgroundLayer.strokeStart = 1.0
        backgroundLayer.strokeEnd = 1.0
        self.layer!.addSublayer(backgroundLayer)

        progressLayer.strokeStart = 1.0
        progressLayer.strokeEnd = 1.0
        self.layer!.addSublayer(progressLayer)

        self.updateLayer()
    }

    override func updateLayer() {
        let bounds = self.layer!.bounds
        let radius = min(bounds.width, bounds.height) * 0.5 - max(lineWidth, backgroundLineWidth)

        progressLayer.frame = CGRect(x: (bounds.width - progressLayer.bounds.width) * 0.5,
                                     y: (bounds.height - progressLayer.bounds.height) * 0.5,
                                     width: progressLayer.bounds.width,
                                     height: progressLayer.bounds.height)
        progressLayer.configureCircle(radius: radius, lineWidth: lineWidth)

        backgroundLayer.frame = CGRect(x: (bounds.width - backgroundLayer.bounds.width) * 0.5,
                                       y: (bounds.height - backgroundLayer.bounds.height) * 0.5,
                                       width: backgroundLayer.bounds.width,
                                       height: backgroundLayer.bounds.height)
        backgroundLayer.configureCircle(radius: radius, lineWidth: backgroundLineWidth)

        progressLayer.strokeColor = self.strokeColor.cgColor
        backgroundLayer.strokeColor = self.backgroundStrokeColor.cgColor
    }

    private enum AnimationKeys {
        static let rotation = "rotation"
        static let stopRotation = "transform"
        static let transformRotation = "transform.rotation"
    }

    override func prepareForReuse() {
        hideProgress(animated: false) {}
        progress = nil
    }

    func setProgress(_ progress: Double?, animated: Bool, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        guard progress != self.progress else {
            completion?(false)
            return
        }
        let oldValue = self.progress
        self.progress = progress

        updateProgressState(oldValue: oldValue, animated: animated) {
            completion?($0)
        }
    }

    private func updateProgressState(oldValue: Double?, animated: Bool, completion: @escaping (Bool) -> Void) {
        let isProgressShown = (backgroundLayer.strokeStart == 0.0 && backgroundLayer.strokeEnd != 0.0)

        guard !isBackgroundAnimating || !animated else {
            // will call `updateProgressState` on animation completion
            completion(false)
            // if background animation is in progress but 1.0 was received before
            // the `progress = nil` update – complete the progress animation
            // before hiding
            if progress == nil && oldValue == 1.0, animated,
               // shouldn‘t be already animating to 100%
               progressLayer.strokeStart != 0.0 {
                updateProgress(from: 0, to: 1, animated: animated) { _ in }
            }
            return
        }

        switch (isProgressShown, (progress != nil)) {
        case (false, true):
            startProgress(animated: animated) { [weak self] in
                self?.updateProgressState(oldValue: oldValue, animated: animated, completion: completion)
            }
        case (true, false):
            hideProgress(animated: animated) {
                completion(true)
            }
        case (true, true):
            updateProgress(from: oldValue, to: progress, animated: animated, completion: completion)
        case (false, false):
            backgroundLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()
            completion(true)
        }
    }

    /// Animate background appearance and then re-call `updateProgress`
    private func startProgress(animated: Bool, completion: @escaping () -> Void) {
        backgroundLayer.strokeEnd = 1.0
        progressLayer.strokeStart = 1.0
        progressLayer.strokeEnd = 1.0

        guard animated else {
            backgroundLayer.strokeStart = 0.0
            completion()
            return
        }
        backgroundLayer.removeAllAnimations()
        progressLayer.removeAllAnimations()

        NSAnimationContext.runAnimationGroup { context in

            context.duration = Constants.animationDuration * animationMultiplier
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)

            let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeStart))
            backgroundLayer.strokeStart = 0.0
            animation.fromValue = 1.0
            animation.isRemovedOnCompletion = true
            backgroundLayer.add(animation, forKey: #keyPath(CAShapeLayer.strokeStart))

        } completionHandler: {
            completion()
        }
    }

    private func updateProgress(from oldValue: Double?, to progress: Double?, animated: Bool, completion: @escaping (Bool) -> Void) {
        guard let progress else {
            assertionFailure("Unexpected flow")
            completion(false)
            return
        }
        let currentStrokeStart = progressLayer.currentStrokeStart
        let newStrokeStart = 1.0 - (progress >= 0.0
                                    ? CGFloat(progress)
                                    : max(Constants.indeterminateProgressValue, min(0.9, 1.0 - currentStrokeStart)))
        guard animated else {
            progressLayer.strokeStart = newStrokeStart

            backgroundLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()

            self.didUpdateProgress(from: oldValue, to: progress, animated: false)
            completion(true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            if oldValue == -1, // is indeterminate?
               currentStrokeStart < newStrokeStart, // is reducing displayed sector?
               !isRotating {

                context.duration = Constants.rotationDuration * animationMultiplier
                // rotate 1 turn when reducing sector from indeterminate to real progress
                // the rotation animation will be limited to 1 turn by calling `stopRotation` below
                self.startRotation(once: true)

            } else {
                context.duration = (progress >= 0.0 ? Constants.animationDuration : (Constants.rotationDuration * Constants.indeterminateProgressValue)) * animationMultiplier
                self.stopRotation()
            }

            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .linear)

            let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeStart))
            progressLayer.removeAnimation(forKey: #keyPath(CAShapeLayer.strokeStart))

            progressLayer.strokeStart = newStrokeStart
            animation.fromValue = currentStrokeStart
            animation.isRemovedOnCompletion = true
            progressLayer.add(animation, forKey: #keyPath(CAShapeLayer.strokeStart))

        } completionHandler: { [weak self] in
            self?.didUpdateProgress(from: oldValue, to: progress, animated: true)
            completion(true)
        }
    }

    private func didUpdateProgress(from oldValue: Double?, to value: Double?, animated: Bool) {
        guard let progress, progress == value else { return }

        if let oldValue, oldValue < 0, value != progress, animated {
            updateProgress(from: value, to: progress, animated: animated) { _ in }
            return
        }

        progressLayer.setValue(0.0, forKeyPath: AnimationKeys.transformRotation)
        if progress < 0.0 {
            self.startRotation()
        }
    }

    /// Start indeterminate progress rotation
    private func startRotation(once: Bool = false) {
        guard progressLayer.animation(forKey: AnimationKeys.rotation) == nil else { return }

        let currentRotation = (progressLayer.presentation() ?? progressLayer)
            .value(forKeyPath: AnimationKeys.transformRotation) as? CGFloat ?? 0.0
        progressLayer.removeAnimation(forKey: AnimationKeys.stopRotation)

        let rotation = CABasicAnimation(keyPath: AnimationKeys.transformRotation)
        rotation.fromValue = currentRotation
        rotation.toValue = currentRotation - CGFloat.pi * 2
        rotation.duration = Constants.rotationDuration * animationMultiplier
        rotation.repeatCount = once ? 1 : .greatestFiniteMagnitude
        rotation.isRemovedOnCompletion = once

        progressLayer.add(rotation, forKey: AnimationKeys.rotation)
    }

    private var isRotating: Bool {
        progressLayer.animation(forKey: AnimationKeys.rotation) != nil
        && progressLayer.animation(forKey: AnimationKeys.stopRotation) == nil
    }
    /// Stop indeterminate progress rotation
    private func stopRotation() {
        guard isRotating else { return }
        if progressLayer.animation(forKey: AnimationKeys.rotation)?.isRemovedOnCompletion == true { return }

        let currentRotation = (progressLayer.presentation() ?? progressLayer)?
            .value(forKeyPath: AnimationKeys.transformRotation) as? CGFloat ?? 0.0
        progressLayer.removeAnimation(forKey: AnimationKeys.rotation)

        let stopRotationAnimation = CABasicAnimation(keyPath: AnimationKeys.transformRotation)
        stopRotationAnimation.fromValue = currentRotation
        stopRotationAnimation.toValue = -CGFloat.pi * 2
        stopRotationAnimation.isRemovedOnCompletion = true

        progressLayer.add(stopRotationAnimation, forKey: AnimationKeys.stopRotation)
    }

    private func hideProgress(animated: Bool, completion: @escaping () -> Void) {
        guard animated else {
            backgroundLayer.strokeEnd = 1.0
            backgroundLayer.strokeStart = 1.0

            progressLayer.strokeEnd = 1.0
            progressLayer.strokeStart = 1.0

            backgroundLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()

            completion()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration * animationMultiplier
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let backgroundAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
            backgroundLayer.strokeEnd = 0.0
            backgroundAnimation.fromValue = 1.0
            backgroundAnimation.isRemovedOnCompletion = true
            backgroundLayer.add(backgroundAnimation, forKey: #keyPath(CAShapeLayer.strokeEnd))

            let progressEndAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
            progressLayer.strokeEnd = 0.0
            progressEndAnimation.fromValue = 1.0
            progressEndAnimation.isRemovedOnCompletion = true
            progressLayer.add(progressEndAnimation, forKey: #keyPath(CAShapeLayer.strokeEnd))

            let progressAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeStart))
            let currentStrokeStart = progressLayer.currentStrokeStart

            progressLayer.removeAnimation(forKey: #keyPath(CAShapeLayer.strokeStart))
            progressLayer.strokeStart = 0.0
            progressAnimation.fromValue = currentStrokeStart
            progressAnimation.isRemovedOnCompletion = true
            progressLayer.add(progressAnimation, forKey: #keyPath(CAShapeLayer.strokeStart))

            self.stopRotation()

        } completionHandler: {
            completion()
        }
    }

}

private extension CAShapeLayer {

    var currentStrokeStart: CGFloat {
        if animation(forKey: #keyPath(CAShapeLayer.strokeStart)) != nil,
           let presentation = self.presentation() {
            return presentation.strokeStart
        }
        return strokeStart
    }

    func configureCircle(radius: CGFloat, lineWidth: CGFloat) {
        self.bounds = CGRect(x: 0, y: 0, width: (radius + lineWidth) * 2, height: (radius + lineWidth) * 2)

        let rect = NSRect(x: lineWidth, y: lineWidth, width: radius * 2, height: radius * 2)
        self.path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).asCGPath()

        self.lineWidth = lineWidth
        self.fillColor = NSColor.clear.cgColor
    }

}

struct CircularProgress: NSViewRepresentable {

    let lineWidth: CGFloat?
    let backgroundLineWidth: CGFloat?
    let strokeColor: NSColor?
    let backgroundStrokeColor: NSColor?

    @Binding var progress: Double?
    @Binding var slowAnimations: Bool

    init(progress: Binding<Double?>, lineWidth: CGFloat? = nil, backgroundLineWidth: CGFloat? = nil, strokeColor: NSColor? = nil, backgroundStrokeColor: NSColor? = nil, slowAnimations: Binding<Bool>? = nil) {
        self._progress = progress
        self._slowAnimations = slowAnimations ?? .constant(false)
        self.lineWidth = lineWidth
        self.backgroundLineWidth = backgroundLineWidth
        self.strokeColor = strokeColor
        self.backgroundStrokeColor = backgroundStrokeColor
    }

    func makeNSView(context: Context) -> CircularProgressView {
        CircularProgressView(lineWidth: lineWidth, backgroundLineWidth: backgroundLineWidth, strokeColor: strokeColor, backgroundStrokeColor: backgroundStrokeColor, progress: progress, animationMultiplier: slowAnimations ? 2.0 : 1.0)
    }

    func updateNSView(_ progressView: CircularProgressView, context: Context) {
        let animated = context.transaction.animation != nil
        progressView.setProgress(progress, animated: animated)
        progressView.animationMultiplier = slowAnimations ? 2.0 : 1.0
    }

}

#if DEBUG
struct ProgressPreview: View {

    @State var animate = true
    @State var slowAnimations = true
    @State var progress: Double?

    private var mult: Double { slowAnimations ? 2 : 1 }

    func perform(_ change: @escaping () -> Void) {
        if animate {
            withAnimation(.default, change)
        } else {
            change()
        }
    }

    var body: some View {
        HStack {
            VStack {
                Toggle(isOn: $animate) {
                    Text(verbatim: "Animate")
                }
                Toggle(isOn: $slowAnimations) {
                    Text(verbatim: "Slow animations")
                }
                Divider()

                Button {
                    perform {
                        progress = nil
                    }
                } label: {
                    Text(verbatim: "Reset (nil)").frame(width: 120)
                }
                Button {
                    perform {
                        progress = -1
                    }
                } label: {
                    Text(verbatim: "Indeterminate (-1)").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 0
                    }
                } label: {
                    Text(verbatim: "Zero").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 0.1
                    }
                } label: {
                    Text(verbatim: "10%").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 0.2
                    }
                } label: {
                    Text(verbatim: "20%").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 0.5
                    }
                } label: {
                    Text(verbatim: "50%").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 0.8
                    }
                } label: {
                    Text(verbatim: "80%").frame(width: 120)
                }
                Button {
                    perform {
                        progress = 1
                    }
                } label: {
                    Text(verbatim: "100%").frame(width: 120)
                }
                Divider()

                Button {
                    Task {
                        progress = nil
                        perform {
                            progress = 0
                        }
                        try await Task.sleep(interval: 0.1)

                        perform {
                            progress = nil
                        }
                    }
                } label: {
                    Text(verbatim: "nil->0->nil").frame(width: 120)
                }

                Button {
                    Task {
                        perform {
                            progress = 0
                        }
                        try await Task.sleep(interval: 0.1)
                        perform {
                            progress = 1
                        }
                        Task {
                            perform {
                                progress = nil
                            }
                        }
                    }
                } label: {
                    Text(verbatim: "0->1->nil").frame(width: 120)
                }

                Button {
                    Task {
                        progress = nil
                        perform {
                            progress = 1
                        }
                        Task {
                            perform {
                                progress = nil
                            }
                        }
                    }
                } label: {
                    Text(verbatim: "nil->1->nil").frame(width: 120)
                }

                Button {
                    Task {
                        progress = nil
                        perform {
                            progress = 1
                        }
                        Task {
                            perform {
                                progress = nil
                            }
                            Task {
                                perform {
                                    progress = 1
                                }
                                Task {
                                    perform {
                                        progress = nil
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Text(verbatim: "nil->1->nil->1->nil").frame(width: 120)
                }

                Button {
                    Task {
                        progress = nil
                        perform {
                            progress = 1
                        }
                        Task {
                            perform {
                                progress = nil
                            }
                            Task {
                                perform {
                                    progress = nil
                                }
                            }
                        }
                    }
                } label: {
                    Text(verbatim: "nil->1->nil->nil").frame(width: 120)
                }

                Button {
                    Task {
                        progress = nil
                        perform {
                            progress = 0
                        }
                        try await Task.sleep(interval: 0.2)
                        for p in [0.26, 0.64, 0.95, 1, nil] {
                            perform {
                                progress = p
                            }
                            try await Task.sleep(interval: 0.001)
                        }
                    }
                } label: {
                    Text(verbatim: "nil->0.2…1->nil").frame(width: 120)
                }

                Button {
                    Task {
                        perform {
                            progress = -1
                        }
                        try await Task.sleep(interval: 0.8 * mult)
                        perform {
                            progress = 0
                        }
                        try await Task.sleep(interval: 0.2 * mult)
                        perform {
                            progress = 0.1
                        }

                        for i in 2...10 {
                            try await Task.sleep(interval: 0.2 * mult)
                            perform {
                                progress = Double(i) / 10
                            }
                        }
                        try await Task.sleep(interval: 0.2 * mult)
                        perform {
                            progress = nil
                        }
                    }
                } label: {
                    Text(verbatim: "-1 -> 0 ... 1").frame(width: 120)
                }

                Spacer()
            }
            .frame(width: 150)
            .padding()

            Divider()

            HStack {
                Spacer()
                CircularProgress(progress: $progress, lineWidth: 10, backgroundLineWidth: 8, slowAnimations: $slowAnimations)
                    .frame(width: 150, height: 150)
                    .background(Color.white)
                Spacer()
            }
        }.frame(width: 600, height: 500)
    }
}

#Preview {
    ProgressPreview()
}
#endif
