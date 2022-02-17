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
        // Prevent Popover detaching on Alert appearance
        self.behavior = .semitransient
        self.delegate = self

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }
    
    var numberOfCloseRequestsToIgnore = 0
    
    override func close() {
        if DeviceAuthenticator.shared.isAuthenticating {
            numberOfCloseRequestsToIgnore = 2
        } else if numberOfCloseRequestsToIgnore > 0 {
            // This means that the previous close request was due to authentication.
            // When this happens, another close request comes in right after for some reason, so ignore that too, but allow future requests.
            numberOfCloseRequestsToIgnore -= 1
            return
        } else {
            super.close()
        }
    }

    // swiftlint:disable force_cast
    var viewController: PasswordManagementViewController { contentViewController as! PasswordManagementViewController }
    // swiftlint:enable force_cast

    private var parentWindowDidResignKeyObserver: Any?
    private var parentWindowDidBecomeKeyObserver: Any?

    func select(category: SecureVaultSorting.Category?) {
        viewController.select(category: category)
    }
    
    private func setupContentController() {
        let controller = PasswordManagementViewController.create()
        contentViewController = controller
    }

}

extension PasswordManagementPopover: NSPopoverDelegate {

    func popoverDidShow(_ notification: Notification) {
        parentWindowDidBecomeKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification,
                                                                                  object: nil,
                                                                                  queue: OperationQueue.main) { [weak self] _ in
            guard let self = self, self.isShown else { return }
            // self.close()
        }
        parentWindowDidResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignMainNotification,
                                                                                  object: nil,
                                                                                  queue: OperationQueue.main) { [weak self] _ in
            guard let self = self, self.isShown else { return }
            // self.close()
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
        parentWindowDidBecomeKeyObserver = nil
    }

}
