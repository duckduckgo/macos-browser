//
//  AddressBarButtonsBadgeAnimator.swift
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

import Cocoa

final class NavigationBarBadgeAnimator: NSObject {
    var queuedAnimation: NavigationBarBadgeAnimationView.AnimationType?
    private var animationID: UUID?
    private(set) var isAnimating = false

    func showNotification(withType type: NavigationBarBadgeAnimationView.AnimationType,
                          buttonsContainer: NSView,
                          and notificationBadgeContainer: NavigationBarBadgeAnimationView) {
        queuedAnimation = nil
        
        isAnimating = true
        let animationDuration: CGFloat = 0.5
        let newAnimationID = UUID()
        self.animationID = newAnimationID
        
        notificationBadgeContainer.prepareAnimation(.cookieManaged)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            buttonsContainer.animator().alphaValue = 0
            notificationBadgeContainer.animator().alphaValue = 1
        } completionHandler: {
            notificationBadgeContainer.startAnimation { [weak self] in
                if self?.animationID == newAnimationID {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = animationDuration
                        buttonsContainer.animator().alphaValue = 1
                        notificationBadgeContainer.animator().alphaValue = 0
                    } completionHandler: {
                        self?.isAnimating = false
                    }
                }
            }
        }
    }
}
