//
//  MockAutofillPopoverPresenter.swift
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
@testable import DuckDuckGo_Privacy_Browser
import Foundation

final class MockAutofillPopoverPresenter: AutofillPopoverPresenter {

    var didShowWithCategory = false
    var didShowWithSelectedAccount = false
    var didDismiss = false
    var isDirty = false
    var isShown = false

    var passwordDomain: String?

    var popoverIsDirty: Bool {
        isDirty
    }
    var popoverIsShown: Bool {
        isShown
    }

    var popoverPresentingWindow: NSWindow?

    func show(positionedBelow view: NSView, withDomain domain: String?, selectedCategory category: DuckDuckGo_Privacy_Browser.SecureVaultSorting.Category?) -> NSPopover {
        didShowWithCategory = true
        return NSPopover()
    }

    func show(positionedBelow view: NSView, withSelectedAccount: BrowserServicesKit.SecureVaultModels.WebsiteAccount) -> NSPopover {
        didShowWithSelectedAccount = true
        return NSPopover()
    }

    func dismiss() {
        didDismiss = true
    }
}
