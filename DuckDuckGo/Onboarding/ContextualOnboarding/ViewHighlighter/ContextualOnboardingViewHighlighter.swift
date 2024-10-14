//
//  ContextualOnboardingViewHighlighter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Lottie

enum ContextualOnboardingViewHighlighter {

    private static let identifier = "lottie_pulse_animation_view"

    static func highlight(view: NSView, inParent parent: NSView) {
        // Avoid duplicate animations
        guard !isViewHighlighted(view) else { return }

        let animationView = LottieAnimationView.makePulseAnimationView()
        animationView.identifier = NSUserInterfaceItemIdentifier(identifier)
        let multiplier = 2.5
        parent.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: multiplier),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: multiplier),
        ])
    }

    static func stopHighlighting(view: NSView) {
        guard let view = findViewWithIdentifier(in: view, identifier: NSUserInterfaceItemIdentifier(identifier)) else { return }
        view.removeFromSuperview()
    }

    static func isViewHighlighted(_ view: NSView) -> Bool {
        findViewWithIdentifier(in: view, identifier: NSUserInterfaceItemIdentifier(identifier)) != nil
    }

    private static func findViewWithIdentifier(in view: NSView, identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        // Check the current view's superview
        // If no matching view is found, return nil
        guard let superview = view.superview else { return nil }

        // Check all subviews of the superview
        for subview in superview.subviews where subview.identifier == identifier {
            return subview
        }

        // Recursively check the superview's superview
        return findViewWithIdentifier(in: superview, identifier: identifier)

    }

}

extension LottieAnimationView {

    static func makePulseAnimationView() -> LottieAnimationView {
        let animation = LottieAnimation.named("view_highlight")
        let animationView = LottieAnimationView(animation: animation)
        animationView.contentMode = .scaleToFill
        animationView.loopMode = .loop
        animationView.play()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        return animationView
    }

}
