//
//  MouseOverAnimationButton.swift
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

import AppKit
import Combine
import Foundation
import Lottie

final class MouseOverAnimationButton: AddressBarButton {

    // MARK: - Events

    override func awakeFromNib() {
        super.awakeFromNib()

        subscribeToIsMouseOver()
        subscribeToEffectiveAppearance()
    }

    private var isMouseOverCancellable: AnyCancellable?

    var isAnimationEnabled: Bool = true

    private func subscribeToIsMouseOver() {
        isMouseOverCancellable = publisher(for: \.isMouseOver)
            .dropFirst()
            .sink { [weak self] isMouseOver in
                guard let self, self.isAnimationEnabled else { return }

                if isMouseOver {
                    self.animate()
                } else {
                    self.stopAnimation()
                }
            }
    }

    private var effectiveAppearanceCancellable: AnyCancellable?

    private func subscribeToEffectiveAppearance() {
        effectiveAppearanceCancellable = NSApp.publisher(for: \.effectiveAppearance)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAnimationView()
            }
    }

    // MARK: - Loading & Updating of Animation Views

    struct AnimationNames: Equatable {
        let aqua: String
        let dark: String
    }

    var animationNames: AnimationNames? {
        didSet {
            if oldValue != animationNames {
                loadAnimationViews()
                updateAnimationView()
            }
        }
    }

    struct AnimationViews {
        let aqua: LottieAnimationView
        let dark: LottieAnimationView
    }

    private var animationViewCache: AnimationViews?

    private func loadAnimationViews() {
        guard let animationNames = animationNames,
              let aquaAnimationView = LottieAnimationView(named: animationNames.aqua),
              let darkAnimationView = LottieAnimationView(named: animationNames.dark) else {
            assertionFailure("Missing animation names or animation files in the bundle")
            return
        }

        animationViewCache = AnimationViews(
            aqua: aquaAnimationView,
            dark: darkAnimationView)
    }

    private var currentAnimationView: LottieAnimationView?

    private func updateAnimationView() {
        guard let animationViewCache = animationViewCache else {
            return
        }

        let isAquaMode = NSApp.effectiveAppearance.name == .aqua
        let newAnimationView: LottieAnimationView
        // Animation view causes problems in tests
        if case .normal = NSApp.runType {
            newAnimationView = isAquaMode ? animationViewCache.aqua : animationViewCache.dark
        } else {
            newAnimationView = LottieAnimationView()
        }

        guard currentAnimationView?.identifier != newAnimationView.identifier else {
            // No need to update
            return
        }

        currentAnimationView?.removeFromSuperview()
        currentAnimationView = newAnimationView

        newAnimationView.isHidden = true
        addAndLayout(newAnimationView)
    }

    // MARK: - Animating

    @Published var isAnimationViewVisible = false

    override var image: NSImage? {
        get {
            return super.image
        }

        set {
            if imageCache !== newValue {
                imageCache = newValue
            }
            if !isAnimationViewVisible {
                super.image = newValue
            }
        }
    }

    var imageCache: NSImage?

    private func hideImage() {
        super.image = nil
    }

    private func showImage() {
        if let imageCache = imageCache {
            NSAppearance.withAppAppearance {
                image = imageCache
            }
        }
    }

    private func hideAnimation() {
        currentAnimationView?.isHidden = true
        isAnimationViewVisible = false
    }

    private func showAnimation() {
        currentAnimationView?.isHidden = false
        isAnimationViewVisible = true
    }

    private func animate() {
        hideImage()
        showAnimation()
        currentAnimationView?.play()
    }

    private func stopAnimation() {
        hideAnimation()
        showImage()
        currentAnimationView?.stop()
    }

}
