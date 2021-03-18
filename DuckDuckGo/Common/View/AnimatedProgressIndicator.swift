//
//  AnimatedProgressIndicator.swift
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

final class AnimatedProgressIndicator: NSProgressIndicator, NSAnimationDelegate {

    private var animation: NSAnimation?
    private var completion: (() -> Void)?

    override var doubleValue: Double {
        get {
            super.doubleValue
        }
        set {
            animation?.stop()
            super.doubleValue = newValue
        }
    }

    private func setSuperDoubleValue(_ value: Double) {
        super.doubleValue = value
    }

    func setValue(_ finalValue: Double, animationDuration duration: TimeInterval, completion: (() -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))

        let initialValue = self.doubleValue
        if let animation = self.animation {
            animation.stop()
        }

        let animation = Animation(duration: duration, curve: .easeIn, blockingMode: .nonblockingThreaded) { [weak self] in
            let value = initialValue + ((finalValue - initialValue) * Double($0))
            self?.setSuperDoubleValue(value)
        }

        self.animation = animation
        self.completion = completion

        animation.delegate = self
        animation.start()
    }

    func animationDidEnd(_ animation: NSAnimation) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  animation === self.animation,
                  let completion = self.completion
            else { return }

            completion()
            self.completion = nil
        }
    }

    func animationDidStop(_ animation: NSAnimation) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.animation === animation
            else { return }

            self.animation = nil
        }
    }

}
