//
//  TabLoadingView.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

final class TabLoadingView: NSView {

    static var images: [NSImage] = {
        var images = [NSImage]()
        for i in 0..<120 {
            if let image = NSImage(named: "Loading-\(i)") {
                images.append(image)
            }
        }
        return images
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
    }

    func startAnimation() {
        layer?.add(animation, forKey: Constants.animationKeyPath)
    }

    func stopAnimation() {
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
        keyFrameAnimation.repeatCount = .infinity
        keyFrameAnimation.autoreverses = false
        keyFrameAnimation.isRemovedOnCompletion = false
        keyFrameAnimation.beginTime = 0.0
        keyFrameAnimation.duration = 4
        return keyFrameAnimation
    }()
    
}
