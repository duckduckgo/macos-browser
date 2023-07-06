//
//  BlurTextField.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import CoreImage

final class BlurringView: NSView {

    private var visualEffectView: NSVisualEffectView?

    var shouldBlur: Bool = false {
        didSet {
            setupVisualEffectView()
            needsDisplay = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        visualEffectView?.isHidden = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        visualEffectView?.isHidden = false
    }

    private func setupVisualEffectView() {
        if shouldBlur {
            let blurView = NSVisualEffectView()
            blurView.blendingMode = .withinWindow
            blurView.state = .active
            blurView.material = .fullScreenUI
            addSubview(blurView)
            blurView.frame = self.bounds
            visualEffectView = blurView
        } else {
            visualEffectView?.removeFromSuperview()
            visualEffectView = nil
        }
    }

    override func layout() {
        super.layout()
        visualEffectView?.frame = self.bounds
    }
}
