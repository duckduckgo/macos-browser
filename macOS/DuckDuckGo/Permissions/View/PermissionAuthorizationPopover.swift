//
//  PermissionAuthorizationPopover.swift
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

final class PermissionAuthorizationPopover: NSPopover {

    @nonobjc private var didShow: Bool = false

    override init() {
        super.init()

        behavior = .applicationDefined
        setupContentController()
        self.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("PermissionAuthorizationPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: PermissionAuthorizationViewController { contentViewController as! PermissionAuthorizationViewController }
    // swiftlint:enable force_cast

    // swiftlint:disable force_cast
    private func setupContentController() {
        let storyboard = NSStoryboard(name: "PermissionAuthorization", bundle: nil)
        let controller = storyboard
            .instantiateController(withIdentifier: "PermissionAuthorizationViewController") as! PermissionAuthorizationViewController
        contentViewController = controller
    }
    // swiftlint:enable force_cast

}

extension PermissionAuthorizationPopover: NSPopoverDelegate {

    func popoverWillShow(_ notification: Notification) {
        self.didShow = false
    }

    func popoverDidShow(_ notification: Notification) {
        self.didShow = true
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard didShow else { return false } // don't close on mouse-up
        return true
    }

}
