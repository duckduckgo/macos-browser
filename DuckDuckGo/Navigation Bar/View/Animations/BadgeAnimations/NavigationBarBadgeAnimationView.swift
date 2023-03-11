//
//  NavigationBarBadgeAnimationView.swift
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

protocol NotificationBarViewAnimated: NSView {
    func startAnimation(_ completion: @escaping () -> Void)
}

final class NavigationBarBadgeAnimationView: NSView {
    var animatedView: NotificationBarViewAnimated?

    enum AnimationType {
        case cookiePopupManaged
        case cookiePopupHidden
    }

    func prepareAnimation(_ type: AnimationType) {
        removeAnimation()
        let viewToAnimate: NotificationBarViewAnimated
        switch type {
        case .cookiePopupHidden:
            viewToAnimate = CookieManagedNotificationContainerView(isCosmetic: true)
        case .cookiePopupManaged:
            viewToAnimate = CookieManagedNotificationContainerView(isCosmetic: false)
        }

        addSubview(viewToAnimate)
        animatedView = viewToAnimate
        setupConstraints()
    }

    func startAnimation(completion: @escaping () -> Void) {
         self.animatedView?.startAnimation(completion)
    }

    func removeAnimation() {
        animatedView?.removeFromSuperview()
    }

    private func setupConstraints() {
        guard let animatedView = animatedView else {
            return
        }

        animatedView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            animatedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animatedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animatedView.bottomAnchor.constraint(equalTo: bottomAnchor),
            animatedView.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
}
