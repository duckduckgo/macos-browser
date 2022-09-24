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

    override init() {
        super.init()

#if DEBUG
        behavior = .semitransient
#else
        behavior = .transient
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

}
