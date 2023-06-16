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
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
final class PrivacyDashboardPopover: NSPopover, Injectable {
    let dependencies: DependencyStorage

    typealias InjectedDependencies = PrivacyDashboardViewController.Dependencies

    init(dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)
        super.init()

#if DEBUG
        behavior = .semitransient
#else
        behavior = .transient
#endif

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: PrivacyDashboardViewController { contentViewController as! PrivacyDashboardViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let storyboard = NSStoryboard(name: "PrivacyDashboard", bundle: nil)
        let controller = storyboard.instantiateController(identifier: "PrivacyDashboardViewController") { [dependencies] coder in
            PrivacyDashboardViewController(coder: coder, dependencyProvider: dependencies)
        }
        contentViewController = controller
    }

    func setPreferredMaxHeight(_ height: CGFloat) {
        viewController.setPreferredMaxHeight(height - 40) // Account for popover arrow height
    }

}
