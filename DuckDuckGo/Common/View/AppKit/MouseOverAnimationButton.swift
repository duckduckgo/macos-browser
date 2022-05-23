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

import Foundation
import Lottie
import Combine
import AppKit

final class MouseOverAnimationButton: AddressBarButton {

    // MARK: - Events

    override func awakeFromNib() {
        super.awakeFromNib()

        subscribeToIsMouseOver()
        subscribeToEffectiveAppearance()
    }

    private var isMouseOverCancellable: AnyCancellable?
    private var keyWindowCancellable: AnyCancellable?

    private func subscribeToIsMouseOver() {
        isMouseOverCancellable = $isMouseOver
            .dropFirst()
            .sink { [weak self] isMouseOver in
                if isMouseOver {
                    self?.animate()
                } else {
                    DispatchQueue.main.async {
                        self?.stopAnimationIfNeeded()
                    }
                }
            }
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }

        keyWindowCancellable = NSApp.publisher(for: \.keyWindow)
            .combineLatest(NSApp.isActivePublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if NSApp.isActive
                    && self?.window?.isKeyWindow == true
                    && self?.isFirstResponder == true {

                    self?.animate()
                } else {
                    self?.stopAnimationIfNeeded()
                }
        }

        return true
    }

    override func resignFirstResponder() -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.stopAnimationIfNeeded()
        }

        self.keyWindowCancellable = nil
        return super.resignFirstResponder()
    }

    override var state: NSControl.StateValue {
        didSet {
            switch state {
            case .on:
                self.animate()
            default:
                self.stopAnimationIfNeeded()
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
        let aqua: AnimationView
        let dark: AnimationView
    }

    private var animationViewCache: AnimationViews?

    private func loadAnimationViews() {
        guard let animationNames = animationNames,
              let aquaAnimationView = AnimationView(named: animationNames.aqua),
              let darkAnimationView = AnimationView(named: animationNames.dark) else {
            assertionFailure("Missing animation names or animation files in the bundle")
            return
        }

        animationViewCache = AnimationViews(
            aqua: aquaAnimationView,
            dark: darkAnimationView)
    }

    private var currentAnimationView: AnimationView?

    private func updateAnimationView() {
        guard let animationViewCache = animationViewCache else {
            return
        }

        let isAquaMode = NSApp.effectiveAppearance.name == NSAppearance.Name.aqua
        let newAnimationView: AnimationView
        // Animation view causes problems in tests
        if AppDelegate.isRunningTests {
            newAnimationView = AnimationView()
        } else {
            newAnimationView = isAquaMode ? animationViewCache.aqua : animationViewCache.dark
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
            if isAnimationViewVisible {
                guard let newValue = newValue else { return }
                imageCache = newValue
            } else {
                super.image = newValue
            }
        }
    }

    private var imageCache: NSImage?

    private func hideImage() {
        guard let image = image else { return }

        imageCache = image
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

    private func stopAnimationIfNeeded() {
        guard !isMouseOver,
              !(NSApp.isActive && self.window?.isKeyWindow == true && self.isFirstResponder),
              case .off = self.state
        else {
            return
        }

        self.stopAnimation()
    }

}
