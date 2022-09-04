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
    
    func showAnimatedAccessoryView(_ view: NSView) {
//        guard self.subviews.isEmpty else {
//            return
//        }

        view.wantsLayer = true

        let originalMaskToBounds = self.layer?.masksToBounds ?? false
        self.layer?.masksToBounds = false

        view.frame.origin = CGPoint(x: -view.frame.midX, y: -view.frame.midY)
        view.alphaValue = 0
        self.addSubview(view)
        
        // Fade in:
        
        var initialTransform = CATransform3DIdentity
        initialTransform = CATransform3DTranslate(initialTransform, view.bounds.midX, view.bounds.midY, 0)
        initialTransform = CATransform3DScale(initialTransform, 2, 2, 1)
        initialTransform = CATransform3DTranslate(initialTransform, view.bounds.midX, view.bounds.midY, 0)
        
        let shrinkSpringAnimation = CASpringAnimation(keyPath: "transform")
        shrinkSpringAnimation.damping = 17
        shrinkSpringAnimation.stiffness = 300
        shrinkSpringAnimation.fromValue = NSValue(caTransform3D: initialTransform)
        shrinkSpringAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        shrinkSpringAnimation.initialVelocity = 35
        shrinkSpringAnimation.duration = shrinkSpringAnimation.settlingDuration
        
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.beginTime = 0.0
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.duration = shrinkSpringAnimation.settlingDuration
        
        print("SETTLING: \(shrinkSpringAnimation.settlingDuration)")
        
        // Fade out:
        
        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        fadeOutAnimation.beginTime = shrinkSpringAnimation.settlingDuration
        fadeOutAnimation.fromValue = 1.0
        fadeOutAnimation.toValue = 0.0
        fadeOutAnimation.duration = 0.3
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [fadeInAnimation, shrinkSpringAnimation, fadeOutAnimation]
        animationGroup.duration = shrinkSpringAnimation.settlingDuration + 0.3
        animationGroup.isRemovedOnCompletion = false
        
        view.layer?.add(animationGroup, forKey: "animationGroup")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shrinkSpringAnimation.settlingDuration + 0.3) {
            view.removeFromSuperview()
        }
    }
    
}
