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
import PrivacyDashboard

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

    var viewController: PrivacyDashboardViewController {
        (contentViewController as? PrivacyDashboardViewController)!
    }

    init(entryPoint: PrivacyDashboardEntryPoint = .dashboard) {
        super.init()
#if DEBUG
        self.behavior = .semitransient
#else
        self.behavior = .transient
#endif
        setupContentController(entryPoint: entryPoint)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    private func setupContentController(entryPoint: PrivacyDashboardEntryPoint) {
        let controller = PrivacyDashboardViewController(entryPoint: entryPoint)
        controller.sizeDelegate = self
        contentViewController = controller
    }

    func setPreferredMaxHeight(_ height: CGFloat) {
        viewController.setPreferredMaxHeight(height - 40) // Account for popover arrow height
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}

extension PrivacyDashboardPopover: PrivacyDashboardViewControllerSizeDelegate {

    func privacyDashboardViewControllerDidChange(size: NSSize) {
        self.contentSize = size
    }
}
