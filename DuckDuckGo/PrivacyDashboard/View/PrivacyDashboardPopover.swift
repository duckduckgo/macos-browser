//
//  PrivacyDashboardPopover.swift
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

import Cocoa

final class PrivacyDashboardPopover: NSPopover {

    private weak var addressBar: NSView?

    /// prefferred bounding box for the popover positioning
    override var boundingFrame: NSRect {
        guard let addressBar,
              let window = addressBar.window else { return .infinite }
        var frame = window.convertToScreen(addressBar.convert(addressBar.bounds, to: nil))

        frame = frame.insetBy(dx: -36, dy: -window.frame.size.height)

        return frame
    }

    override init() {
        super.init()

        self.animates = false
#if DEBUG
        self.behavior = .semitransient
#else
        self.behavior = .transient
#endif

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("PrivacyDashboardPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: PrivacyDashboardViewController { contentViewController as! PrivacyDashboardViewController }
    // swiftlint:enable force_cast

    // swiftlint:disable force_cast
    private func setupContentController() {
        let storyboard = NSStoryboard(name: "PrivacyDashboard", bundle: nil)
        let controller = storyboard
            .instantiateController(withIdentifier: "PrivacyDashboardViewController") as! PrivacyDashboardViewController
        contentViewController = controller
    }
    // swiftlint:enable force_cast

    func setPreferredMaxHeight(_ height: CGFloat) {
        viewController.setPreferredMaxHeight(height - 40) // Account for popover arrow height
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

}
