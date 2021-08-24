//
//  PrivacyEntryPointAddressBarButton.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Combine

final class PrivacyEntryPointAddressBarButton: AddressBarButton {

    static var lightAnimationImages: [NSImage] = {
        var images = [NSImage]()
        for i in 0...150 {
            if let image = NSImage(named: "PrivacyIconLight\(String(format: "%03d", i))") {
                images.append(image)
            }
        }
        return images
    }()
    static var darkAnimationImages: [NSImage] = {
        var images = [NSImage]()
        for i in 0...150 {
            if let image = NSImage(named: "PrivacyIconDark\(String(format: "%03d", i))") {
                images.append(image)
            }
        }
        return images
    }()

    private var animationImages = [NSImage]()
    private var cancellables = Set<AnyCancellable>()

    override func awakeFromNib() {
        super.awakeFromNib()

        subscribeToEffectiveAppearance()
    }

    func animate() {
        guard layer?.animation(forKey: Constants.animationKeyPath) == nil else { return }
        layer?.add(animation, forKey: Constants.animationKeyPath)
    }

    func reset() {
        layer?.removeAnimation(forKey: Constants.animationKeyPath)
        image = animationImages.first
    }

    func setFinal() {
        image = animationImages.last
        layer?.removeAnimation(forKey: Constants.animationKeyPath)
    }

    private func subscribeToEffectiveAppearance() {
        NSApp.publisher(for: \.effectiveAppearance)
            .sink { [weak self] _ in
                self?.updateAnimationImages()
            }
            .store(in: &cancellables)
    }

    private enum Constants {
        static let animationKeyPath = "contents"
    }

    private lazy var animation: CAKeyframeAnimation = {
        let keyFrameAnimation = CAKeyframeAnimation(keyPath: Constants.animationKeyPath)
        keyFrameAnimation.values = animationImages
        keyFrameAnimation.calculationMode = .discrete
        keyFrameAnimation.fillMode = .forwards
        keyFrameAnimation.autoreverses = false
        keyFrameAnimation.isRemovedOnCompletion = false
        keyFrameAnimation.beginTime = 0
        keyFrameAnimation.duration = Double(animationImages.count) / 30.0
        return keyFrameAnimation
    }()

    private func updateAnimationImages() {
        animationImages.removeAll()

        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            animationImages = Self.lightAnimationImages
        } else {
            animationImages = Self.darkAnimationImages
        }
        animation.values = animationImages
    }

}
