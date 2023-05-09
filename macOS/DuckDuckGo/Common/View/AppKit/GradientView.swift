//
//  GradientView.swift
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

final class GradientView: NSView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupView()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setupView()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        setupView()
        setupGradientView()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()

        setupGradientView()
    }

    @IBInspectable var backgroundColor1: NSColor? = NSColor.clear
    @IBInspectable var backgroundColor2: NSColor? = NSColor.clear
    @IBInspectable var startPoint: CGPoint = CGPoint(x: 0.0, y: 0.5)
    @IBInspectable var endPoint: CGPoint = CGPoint(x: 1.0, y: 0.5)

    func setupGradientView() {
        NSAppearance.withAppAppearance {
            guard let backgroundColor1 = backgroundColor1, let backgroundColor2 = backgroundColor2 else {
                return
            }

            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [backgroundColor1.cgColor, backgroundColor2.cgColor]
            gradientLayer.startPoint = startPoint
            gradientLayer.endPoint = endPoint
            gradientLayer.frame = bounds

            layer = gradientLayer
        }
    }

    private var effectView: NSVisualEffectView?

    private func setupView() {
        self.wantsLayer = true
    }

}
