//
//  AutofillCredentialsImportManagerTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
@testable import BrowserServicesKit

final class AutofillCredentialsImportManagerTests: XCTestCase {

    private var manager: AutofillCredentialsImportManager!
    private var importState: MockAutofillLoginImportState!

    override func setUp() {
        super.setUp()
        importState = MockAutofillLoginImportState()
        manager = AutofillCredentialsImportManager(loginImportStateProvider: importState, isBurnerWindow: false)
    }

    override func tearDown() {
        importState = nil
        manager = nil
        super.tearDown()
    }

    func testWhenProviderNameIsBitwarden_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(credentialsProvider: .init(name: .bitwarden, locked: false))

        XCTAssertFalse(result)
    }

    func testWhenCredentialsForDomainAreNotEmpty_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(credentials: createListOfCredentials())

        XCTAssertFalse(result)
    }

    func testWhenTotalCredentialsCountIsFiftyOrMore_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(totalCredentialsCount: 50)

        XCTAssertFalse(result)
    }

    func testWhenUserHasImportedLogins_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(hasUserImportedLogins: true)

        XCTAssertFalse(result)
    }

    func testWhenUserIsEligibleDDGUser_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(isEligibleDDGUser: false)

        XCTAssertFalse(result)
    }

    func testWhenAutofillIsDisabled_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(isAutofillEnabled: false)

        XCTAssertFalse(result)
    }

    func testWhenHasNeverPromptWebsitesIsTrue_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(hasNeverPromptWebsites: true)

        XCTAssertFalse(result)
    }

    func testWhenCredentialsImportPresentationCountIs5_ThenAutofillUserScriptShouldShowPasswordImportDialogIsFalse() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult(isCredentialsImportPromptPermanantlyDismissed: true)

        XCTAssertFalse(result)
    }

    func testWhenAllOtherCredentialsImportConditionsAreMet_ThenAutofillUserScriptShouldShowPasswordImportDialogIsTrue() {
        let result = autofillUserScriptShouldShowPasswordImportDialogResult()

        XCTAssertTrue(result)
    }

    func testWhenPermanentCredentialsImportPromptDismissalIsRequested_ThenStateFlagIsSetToTrue() {
        manager.autofillUserScriptDidRequestPermanentCredentialsImportPromptDismissal()

        XCTAssertTrue(importState.isCredentialsImportPromptPermanantlyDismissed)
    }

    func testOnAutofillUserScriptShouldDisplayOverlay_NonParsableSerializedInputContext_returnsTrue() {
        let result = manager.autofillUserScriptShouldDisplayOverlay("", for: "fill.dev")

        XCTAssertTrue(result)
    }

    func testOnAutofillUserScriptShouldDisplayOverlay_SerializedInputContextWithCredentialsImportFalse_returnsTrue() {
        let result = manager.autofillUserScriptShouldDisplayOverlay("", for: "fill.dev")

        XCTAssertTrue(result)
    }

    func testOnAutofillUserScriptShouldDisplayOverlay_SerializedInputContextWithCredentialsImportTrue_PromptHasNOTBeenPermanantlyDismissed_returnsTrue() {
        importState.isCredentialsImportPromptPermanantlyDismissed = false
        let result = manager.autofillUserScriptShouldDisplayOverlay("", for: "fill.dev")

        XCTAssertTrue(result)
    }

    func testOnAutofillUserScriptShouldDisplayOverlay_SerializedInputContextWithCredentialsImportTrue_PromptHasBeenPermanantlyDismissed_returnsFalse() {
        let serializedInputContext = "{\"inputType\":\"credentials.username\",\"credentialsImport\":true}"
        importState.isCredentialsImportPromptPermanantlyDismissed = true
        let result = manager.autofillUserScriptShouldDisplayOverlay(serializedInputContext, for: "fill.dev")

        XCTAssertFalse(result)
    }

    // Default values here are those that will result in a `true` value for credentialsImport. Override to test `false` case.
    private func autofillUserScriptShouldShowPasswordImportDialogResult(credentials: [SecureVaultModels.WebsiteCredentials] = [],
                                                                        credentialsProvider: SecureVaultModels.CredentialsProvider = SecureVaultModels.CredentialsProvider(name: .duckduckgo, locked: false),
                                                                        totalCredentialsCount: Int = 49,
                                                                        hasUserImportedLogins: Bool = false,
                                                                        isEligibleDDGUser: Bool = true,
                                                                        hasNeverPromptWebsites: Bool = false,
                                                                        isAutofillEnabled: Bool = true,
                                                                        isCredentialsImportPromptPermanantlyDismissed: Bool = false,
                                                                        file: StaticString = #filePath,
                                                                        line: UInt = #line) -> Bool {
        importState.stubHasNeverPromptWebsitesForDomain = hasNeverPromptWebsites
        importState.hasImportedLogins = hasUserImportedLogins
        importState.isCredentialsImportPromptPermanantlyDismissed = isCredentialsImportPromptPermanantlyDismissed
        importState.isAutofillEnabled = isAutofillEnabled
        importState.isEligibleDDGUser = isEligibleDDGUser
        return manager.autofillUserScriptShouldShowPasswordImportDialog(domain: "", credentials: credentials, credentialsProvider: credentialsProvider, totalCredentialsCount: totalCredentialsCount)
    }

    private func createListOfCredentials(withPassword password: Data? = nil) -> [SecureVaultModels.WebsiteCredentials] {
        var credentialsList = [SecureVaultModels.WebsiteCredentials]()
        for i in 0...10 {
            let account = SecureVaultModels.WebsiteAccount(id: "id\(i)", username: "username\(i)", domain: "domain.com", created: Date(), lastUpdated: Date())
            let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: password)
            credentialsList.append(credentials)
        }
        return credentialsList
    }
}

final class MockAutofillLoginImportState: AutofillLoginImportStateStoring, AutofillLoginImportStateProvider {
    var isCredentialsImportPromptPermanantlyDismissed: Bool = false

    var isEligibleDDGUser = false

    var hasImportedLogins = false

    var isAutofillEnabled = false

    var stubHasNeverPromptWebsitesForDomain = false
    func hasNeverPromptWebsitesFor(_ domain: String) -> Bool {
        stubHasNeverPromptWebsitesForDomain
    }
}
