//
//  PasswordManagementPopover.swift
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

import AppKit
import BrowserServicesKit
import SwiftUI

final class PasswordManagementPopover: NSPopover {

    override init() {
        super.init()

        self.animates = false
        self.behavior = .transient
        self.delegate = self

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: PasswordManagementViewController { contentViewController as! PasswordManagementViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let controller = PasswordManagementViewController.create()
        contentViewController = controller
    }

}

extension PasswordManagementPopover: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        viewController.postChange()
        if !viewController.isDirty {
            viewController.clear()
        }
    }

}
