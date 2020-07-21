//
//  RotatingButton.swift
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
import os.log

class RotatingButton: NSButton {

    enum Constants {
        static let rotationAnimationKeyPath = "transform.rotation.z"
        static let rotationAnimationKey = rotationAnimationKeyPath
        static let rotationDuration: Double = 1
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        animation.delegate = self
    }

    override func layout() {
        super.layout()

        setAnimationPoints()
    }

    func startRotation() {
        if !shouldBeRotating {
            shouldBeRotating = true

            addAnimation()
        }
    }

    func stopRotation() {
        shouldBeRotating = false
    }

    private let animation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: Constants.rotationAnimationKeyPath)
        animation.fromValue = 2 * Double.pi
        animation.toValue = 0
        animation.duration = Constants.rotationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = true
        return animation
    }()

    private var shouldBeRotating = false

    private func addAnimation() {
        guard let layer = layer else {
            os_log("RotatingButton: Layer unavailable", log: OSLog.Category.general, type: .error)
            return
        }

        layer.add(animation, forKey: Constants.rotationAnimationKey)
    }

    private func setAnimationPoints() {
        guard let layer = layer else {
            os_log("RotatingButton: Layer unavailable", log: OSLog.Category.general, type: .error)
            return
        }

        layer.position = CGPoint(x: layer.frame.midX, y: layer.frame.midY)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

}

extension RotatingButton: CAAnimationDelegate {

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if shouldBeRotating {
            addAnimation()
        }
    }
}
