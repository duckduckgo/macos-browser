//
//  NavigationBarBadgeAnimator.swift
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

protocol NavigationBarBadgeAnimatorDelegate: AnyObject {
    func didFinishAnimating()
}

final class NavigationBarBadgeAnimator: NSObject {
    var queuedAnimation: QueueData?
    private var animationID: UUID?
    private(set) var isAnimating = false
    weak var delegate: NavigationBarBadgeAnimatorDelegate?

    struct QueueData {
        var selectedTab: Tab?
        var animationType: NavigationBarBadgeAnimationView.AnimationType
    }

    private enum ButtonsFade {
        case start
        case end
    }

    func showNotification(withType type: NavigationBarBadgeAnimationView.AnimationType,
                          buttonsContainer: NSView,
                          and notificationBadgeContainer: NavigationBarBadgeAnimationView) {
        queuedAnimation = nil

        isAnimating = true

        let newAnimationID = UUID()
        self.animationID = newAnimationID

        notificationBadgeContainer.prepareAnimation(type)

        animateButtonsFade(.start,
                           buttonsContainer: buttonsContainer,
                           notificationBadgeContainer: notificationBadgeContainer) {

            notificationBadgeContainer.startAnimation { [weak self] in
                if self?.animationID == newAnimationID {
                    self?.animateButtonsFade(.end,
                                       buttonsContainer: buttonsContainer,
                                       notificationBadgeContainer: notificationBadgeContainer) {
                        self?.isAnimating = false
                        self?.delegate?.didFinishAnimating()
                    }
                }
            }
        }
    }

    private func animateButtonsFade(_ fadeType: ButtonsFade,
                                    buttonsContainer: NSView,
                                    notificationBadgeContainer: NavigationBarBadgeAnimationView,
                                    completionHandler: @escaping (() -> Void)) {

        let animationDuration: CGFloat = 0.25

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            if fadeType == .start {
                buttonsContainer.animator().alphaValue = 0
            } else if fadeType == .end {
                notificationBadgeContainer.animator().alphaValue = 0
            }
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                if fadeType == .start {
                    notificationBadgeContainer.animator().alphaValue = 1
                } else if fadeType == .end {
                    buttonsContainer.animator().alphaValue = 1
                }
            } completionHandler: {
                completionHandler()
            }
        }
    }
}
