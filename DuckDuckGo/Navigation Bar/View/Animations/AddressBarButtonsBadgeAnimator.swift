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

final class AddressBarButtonsBadgeAnimator: NSObject {
    private var animationID: UUID?

    func showNotification(withType type: NavigationBarBadgeAnimationView.AnimationType,
                          buttonsContainer: NSView,
                          and notificationBadgeContainer: NavigationBarBadgeAnimationView) {
        
        let animationDuration: CGFloat = 0.5
        let newAnimationID = UUID()
        self.animationID = newAnimationID
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            buttonsContainer.animator().alphaValue = 0
            notificationBadgeContainer.animator().alphaValue = 1
            
            notificationBadgeContainer.startAnimation(type) { [weak self] in
                if self?.animationID == newAnimationID {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = animationDuration
                        buttonsContainer.animator().alphaValue = 1
                        notificationBadgeContainer.animator().alphaValue = 0
                    }
                }
            }
        }
    }
}
