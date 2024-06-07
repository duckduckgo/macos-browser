//
//  WebViewSnapshotView.swift
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

final class WebViewSnapshotView: NSView {
    let imageView: NSImageView
    let dimmingView: NSView

    init(image: NSImage, frame: NSRect) {
        imageView = NSImageView()
        dimmingView = NSView()
        super.init(frame: frame)

        imageView.image = image
        imageView.imageAlignment = .alignTopLeft
        imageView.imageScaling = .scaleProportionallyUpOrDown

        dimmingView.wantsLayer = true
        dimmingView.alphaValue = 0
        updateDimColor()

        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addAndLayout(imageView)
        addAndLayout(dimmingView)
    }

    override func viewDidChangeEffectiveAppearance() {
        updateDimColor()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        NSAnimationContext.runAnimationGroup { context in
            context.allowsImplicitAnimation = true
            context.duration = 0.5

            dimmingView.animator().alphaValue = 0.8
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateDimColor() {
        NSAppearance.withAppAppearance {
            dimmingView.layer?.backgroundColor = NSColor.windowBackground.withAlphaComponent(1.0).cgColor
        }
    }
}
