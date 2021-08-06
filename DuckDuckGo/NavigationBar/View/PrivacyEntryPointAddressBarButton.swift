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

final class PrivacyEntryPointAddressBarButton: AddressBarButton {

    static var images: [NSImage] = {
        var images = [NSImage]()
        for i in 0..<180 {
            if let image = NSImage(named: "PrivacyIcon\(String(format: "%03d", i))") {
                images.append(image)
            }
        }
        return images
    }()

    func animate() {
        guard layer?.animation(forKey: Constants.animationKeyPath) == nil else { return }
        layer?.add(animation, forKey: Constants.animationKeyPath)
    }

    func reset() {
        layer?.removeAnimation(forKey: Constants.animationKeyPath)
        image = Self.images.first
    }

    func setFinal() {
        image = Self.images.last
        layer?.removeAnimation(forKey: Constants.animationKeyPath)
    }

    private enum Constants {
        static let animationKeyPath = "contents"
    }

    private lazy var animation: CAKeyframeAnimation = {
        let keyFrameAnimation = CAKeyframeAnimation(keyPath: Constants.animationKeyPath)
        keyFrameAnimation.values = Self.images
        keyFrameAnimation.calculationMode = .discrete
        keyFrameAnimation.fillMode = .forwards
        keyFrameAnimation.autoreverses = false
        keyFrameAnimation.isRemovedOnCompletion = false
        keyFrameAnimation.beginTime = 0
        keyFrameAnimation.duration = 6
        return keyFrameAnimation
    }()

}
