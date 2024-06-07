//
//  AutofillPopoverPresenter.swift
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

protocol AutofillPopoverPresenter {
    var passwordDomain: String? { get set }
    var popoverIsDirty: Bool { get }
    var popoverIsShown: Bool { get }
    var popoverPresentingWindow: NSWindow? { get }
    func show(positionedBelow view: NSView, withDomain domain: String?, selectedCategory category: SecureVaultSorting.Category?) -> NSPopover
    func show(positionedBelow view: NSView, withSelectedAccount: SecureVaultModels.WebsiteAccount) -> NSPopover
    func dismiss()
}

final class DefaultAutofillPopoverPresenter: AutofillPopoverPresenter, PopoverPresenter {

    private var popover: PasswordManagementPopover?

    var passwordDomain: String? {
        get {
            popover?.viewController.domain
        } set {
            popover?.viewController.domain = newValue
        }
    }

    /// Property indicating whether the popover view controller is "dirty", i.e it's state has been edited but is unsaved
    var popoverIsDirty: Bool {
        popover?.viewController.isDirty ?? false
    }

    var popoverIsShown: Bool {
        popover?.isShown ?? false
    }

    var popoverPresentingWindow: NSWindow? {
        popover?.mainWindow
    }

    /// Note: Dismisses any previously displayed popover before showing a new one
    func show(positionedBelow view: NSView, withDomain domain: String?, selectedCategory category: SecureVaultSorting.Category?) -> NSPopover {
        let popover = show(under: view, withDomain: domain)
        popover.select(category: category)
        return popover
    }

    func show(positionedBelow view: NSView, withSelectedAccount account: SecureVaultModels.WebsiteAccount) -> NSPopover {
        let popover = show(under: view, withDomain: nil)
        popover.select(websiteAccount: account)
        return popover
    }

    func dismiss() {
        guard popoverIsShown, let popover else { return }
        popover.close()
        self.popover = nil
    }
}

private extension DefaultAutofillPopoverPresenter {

    func show(under view: NSView, withDomain domain: String?) -> PasswordManagementPopover {
        dismiss()

        let popover = PasswordManagementPopover()
        self.popover = popover
        popover.viewController.domain = domain
        show(popover, positionedBelow: view)
        return popover
    }
}
