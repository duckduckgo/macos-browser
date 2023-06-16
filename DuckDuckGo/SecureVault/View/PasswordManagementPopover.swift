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
import DependencyInjection
import SwiftUI

#if swift(>=5.9)
@Injectable
#endif
final class PasswordManagementPopover: NSPopover, Injectable {
    let dependencies: DependencyStorage

    typealias InjectedDependencies = PasswordManagementViewController.Dependencies

    init(dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)

        super.init()

        self.animates = false
        // Prevent Popover detaching on Alert appearance
        self.behavior = .semitransient
        self.delegate = self

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: PasswordManagementViewController { contentViewController as! PasswordManagementViewController }
    // swiftlint:enable force_cast

    private var parentWindowDidResignKeyObserver: Any?

    func select(category: SecureVaultSorting.Category?) {
        viewController.select(category: category)
    }

    private func setupContentController() {
        let controller = PasswordManagementViewController.create(dependencyProvider: dependencies)
        contentViewController = controller
    }

}

extension PasswordManagementPopover: NSPopoverDelegate {

    func popoverDidShow(_ notification: Notification) {
        parentWindowDidResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignMainNotification,
                                                                                  object: nil,
                                                                                  queue: OperationQueue.main) { [weak self] _ in
            guard let self = self, self.isShown else { return }

            if !DeviceAuthenticator.shared.isAuthenticating {
                self.close()
            }
        }
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return !DeviceAuthenticator.shared.isAuthenticating
    }

    func popoverDidClose(_ notification: Notification) {
        if let window = viewController.view.window {
            for sheet in window.sheets {
                window.endSheet(sheet, returnCode: .cancel)
            }
        }
        viewController.postChange()
        if !viewController.isDirty {
            viewController.clear()
        }
        parentWindowDidResignKeyObserver = nil
    }

}
