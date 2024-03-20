//
//  FireAnimationView.swift
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

import SwiftUI
import Lottie

struct FireAnimation: NSViewRepresentable {

    static let animation = LottieAnimation.named("01_Fire_really_small", animationCache: LottieAnimationCache.shared)

    func makeNSView(context: NSViewRepresentableContext<FireAnimation>) -> NSView {
        let view = NSView(frame: .zero)

        let animationView = LottieAnimationView(animation: Self.animation)
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .playOnce
        animationView.play { _ in
            animationView.removeFromSuperview()
        }

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }

}
