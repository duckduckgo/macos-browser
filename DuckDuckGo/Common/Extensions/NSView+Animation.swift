//
//  NSView+Animation.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Foundation

extension NSView {
    
    private enum AnimationConstants {
        static let animationKey = "animated-accessory-view-key"
    }
    
    func showAnimatedAccessoryView(_ view: NSView, playsInReverse: Bool = false) {
        if subviews.contains(where: { subview in
            return subview.layer?.animation(forKey: AnimationConstants.animationKey) != nil
        }) { return }

        view.wantsLayer = true

        self.layer?.masksToBounds = false

        if playsInReverse {
            playRemovePinAnimation(view)
        } else {
            playPinAnimation(view)
        }
    }
    
    private func playRemovePinAnimation(_ view: NSView) {
        view.frame.origin = CGPoint(x: -view.frame.midX + 5, y: -view.frame.midY + 5)
        view.alphaValue = 0
        self.addSubview(view)
        
        // Fade in:
        
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.beginTime = 0.0
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.duration = 0.1
        
        let remainFadedInAnimation = CABasicAnimation(keyPath: "opacity")
        remainFadedInAnimation.beginTime = 0.1
        remainFadedInAnimation.fromValue = 1.0
        remainFadedInAnimation.toValue = 1.0
        remainFadedInAnimation.duration = 0.4
        
        // Exit stage:
        
        var initialTransform = CATransform3DIdentity
        initialTransform = CATransform3DTranslate(initialTransform, -10, -10, 0)
        
        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        fadeOutAnimation.beginTime = 0.1 + 0.4
        fadeOutAnimation.fromValue = 1.0
        fadeOutAnimation.toValue = 0.0
        fadeOutAnimation.duration = 0.2
        
        let translation = CATransform3DMakeTranslation(-5, -5, 0)
        let translationAnimation = CABasicAnimation(keyPath: "transform")
        translationAnimation.beginTime = 0.1 + 0.4
        translationAnimation.duration = 0.2
        translationAnimation.fromValue = CATransform3DIdentity
        translationAnimation.toValue = translation
        translationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        
        // Group animations:
        
        let totalAnimationTime = 0.1 + 0.4 + 0.2

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [fadeInAnimation, remainFadedInAnimation, translationAnimation, fadeOutAnimation]
        animationGroup.duration = totalAnimationTime
        animationGroup.isRemovedOnCompletion = false
        
        view.layer?.add(animationGroup, forKey: AnimationConstants.animationKey)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalAnimationTime) {
            view.removeFromSuperview()
        }
    }
    
    private func playPinAnimation(_ view: NSView) {
        view.frame.origin = CGPoint(x: -view.frame.midX + 5, y: -view.frame.midY + 5)
        view.alphaValue = 0
        self.addSubview(view)
        
        // Fade in:
        
        var initialTransform = CATransform3DIdentity
        initialTransform = CATransform3DTranslate(initialTransform, -10, -10, 0)
        
        let shrinkSpringAnimation = CASpringAnimation(keyPath: "transform")
        shrinkSpringAnimation.damping = 20
        shrinkSpringAnimation.stiffness = 300
        shrinkSpringAnimation.fromValue = NSValue(caTransform3D: initialTransform)
        shrinkSpringAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        shrinkSpringAnimation.initialVelocity = 20
        shrinkSpringAnimation.duration = shrinkSpringAnimation.settlingDuration
        
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.beginTime = 0.0
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.duration = shrinkSpringAnimation.settlingDuration
        
        let remainFadedInAnimation = CABasicAnimation(keyPath: "opacity")
        remainFadedInAnimation.beginTime = shrinkSpringAnimation.settlingDuration
        remainFadedInAnimation.fromValue = 1.0
        remainFadedInAnimation.toValue = 1.0
        remainFadedInAnimation.duration = 1.0
        
        // Fade out:
        
        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        fadeOutAnimation.beginTime = 1.0 + shrinkSpringAnimation.settlingDuration
        fadeOutAnimation.fromValue = 1.0
        fadeOutAnimation.toValue = 0.0
        fadeOutAnimation.duration = 0.3
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [fadeInAnimation, shrinkSpringAnimation, remainFadedInAnimation, fadeOutAnimation]
        animationGroup.duration = shrinkSpringAnimation.settlingDuration + 1.0 + 0.3
        animationGroup.isRemovedOnCompletion = false
        
        view.layer?.add(animationGroup, forKey: AnimationConstants.animationKey)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shrinkSpringAnimation.settlingDuration + 1.0 + 0.3) {
            view.removeFromSuperview()
        }
    }
    
}
