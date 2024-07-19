//
//  CapturingOptionsButtonMenuDelegate.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation
@testable import DuckDuckGo_Privacy_Browser

class CapturingOptionsButtonMenuDelegate: OptionsButtonMenuDelegate {

    var optionsButtonMenuRequestedPreferencesCalled = false
    var optionsButtonMenuRequestedAppearancePreferencesCalled = false
    var optionsButtonMenuRequestedAccessibilityPreferencesCalled = false
    var optionsButtonMenuRequestedBookmarkAllOpenTabsCalled = false

    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedSubscriptionPreferences(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem) {

    }

    func optionsButtonMenuRequestedBookmarkAllOpenTabs(_ sender: NSMenuItem) {
        optionsButtonMenuRequestedBookmarkAllOpenTabsCalled = true
    }

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedToggleBookmarksBar(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: DuckDuckGo_Privacy_Browser.SecureVaultSorting.Category) {

    }

    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedPrint(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedPreferences(_ menu: NSMenu) {
        optionsButtonMenuRequestedPreferencesCalled = true
    }

    func optionsButtonMenuRequestedAppearancePreferences(_ menu: NSMenu) {
        optionsButtonMenuRequestedAppearancePreferencesCalled = true
    }

    func optionsButtonMenuRequestedBookmarkExportInterface(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu) {

    }

    func optionsButtonMenuRequestedAccessibilityPreferences(_ menu: NSMenu) {
        optionsButtonMenuRequestedAccessibilityPreferencesCalled = true
    }
}
