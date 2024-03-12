//
//  PasswordPopoverPresenter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Foundation

protocol PasswordPopoverPresenter {
    var passwordDomain: String? { get set }
    var popoverIsDirty: Bool { get }
    var popoverIsDisplayed: Bool { get }
    var popoverIsInCurrentWindow: Bool { get }
    func show(under view: NSView, withDomain domain: String?, selectedCategory category: SecureVaultSorting.Category?)
    func show(under view: NSView, withSelectedAccount: SecureVaultModels.WebsiteAccount)
    func dismiss()
}

final class DefaultPasswordPopoverPresenter: PasswordPopoverPresenter, PopoverPresenter {

    private var popover: PasswordManagementPopover?

    var passwordDomain: String? {
        get {
            popover?.viewController.domain
        } set {
            popover?.viewController.domain = newValue
        }
    }

    var popoverIsDirty: Bool {
        popover?.viewController.isDirty ?? false
    }

    var popoverIsDisplayed: Bool {
        popover?.isShown ?? false
    }

    var popoverIsInCurrentWindow: Bool {
        popover?.mainWindow == NSApplication.shared.keyWindow
    }

    /// Note: Dismisses any previously displayed popover before showing a new one
    func show(under view: NSView, withDomain domain: String?, selectedCategory category: SecureVaultSorting.Category?) {
        show(under: view, withDomain: domain).select(category: category)
    }

    func show(under view: NSView, withSelectedAccount account: SecureVaultModels.WebsiteAccount) {
        show(under: view, withDomain: nil).select(websiteAccount: account)
    }

    func dismiss() {
        guard let popover else { return }
        self.popover?.close()
    }

    private func show(under view: NSView, withDomain domain: String?) -> PasswordManagementPopover {
        dismiss()

        let popover = PasswordManagementPopover()
        self.popover = popover
        popover.viewController.domain = domain
        show(popover, positionedBelow: view)
        return popover
    }
}
