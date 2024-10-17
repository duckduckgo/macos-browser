//
//  AutofillCredentialsImportManager.swift
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

import Foundation
import PixelKit
import BrowserServicesKit

public protocol AutofillCredentialsImportPresentationDelegate: AnyObject {
    func autofillDidRequestCredentialsImportFlow(onFinished: @escaping () -> Void, onCancelled: @escaping () -> Void)
}

public protocol AutofillLoginImportStateProvider {
    var isEligibleDDGUser: Bool { get }
    var hasImportedLogins: Bool { get }
    var isAutofillEnabled: Bool { get }
    var isCredentialsImportPromptPermanantlyDismissed: Bool { get }
    func hasNeverPromptWebsitesFor(_ domain: String) -> Bool
}

final public class AutofillCredentialsImportManager {
    private var loginImportStateProvider: AutofillLoginImportStateProvider & AutofillLoginImportStateStoring
    private let isBurnerWindow: Bool

    weak var presentationDelegate: AutofillCredentialsImportPresentationDelegate?

    init(loginImportStateProvider: AutofillLoginImportStateProvider & AutofillLoginImportStateStoring = AutofillLoginImportState(),
         isBurnerWindow: Bool) {
        self.loginImportStateProvider = loginImportStateProvider
        self.isBurnerWindow = isBurnerWindow
    }
}

extension AutofillCredentialsImportManager: AutofillPasswordImportDelegate {
    private struct CredentialsImportInputContext: Decodable {
        var inputType: String
        var credentialsImport: Bool
    }

    public func autofillUserScriptDidRequestPasswordImportFlow(_ completion: @escaping () -> Void) {
        PixelKit.fire(AutofillPixelKitEvent.importCredentialsFlowStarted.withoutMacPrefix)
        presentationDelegate?.autofillDidRequestCredentialsImportFlow(
            onFinished: {
                PixelKit.fire(AutofillPixelKitEvent.importCredentialsFlowEnded.withoutMacPrefix)
                completion()
            },
            onCancelled: {
                PixelKit.fire(AutofillPixelKitEvent.importCredentialsFlowCancelled.withoutMacPrefix)
                completion()
            }
        )
    }

    public func autofillUserScriptDidFinishImportWithImportedCredentialForCurrentDomain() {
        PixelKit.fire(AutofillPixelKitEvent.importCredentialsFlowHadCredentials.withoutMacPrefix)
    }

    public func autofillUserScriptDidRequestPermanentCredentialsImportPromptDismissal() {
        loginImportStateProvider.isCredentialsImportPromptPermanantlyDismissed = true
        PixelKit.fire(AutofillPixelKitEvent.importCredentialsPromptNeverAgainClicked.withoutMacPrefix)
    }

    public func autofillUserScriptShouldDisplayOverlay(_ serializedInputContext: String, for domain: String) -> Bool {
        if let data = serializedInputContext.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CredentialsImportInputContext.self, from: data) {
            if decoded.credentialsImport {
                return !loginImportStateProvider.isCredentialsImportPromptPermanantlyDismissed
            }
        }
        return true
    }

    public func autofillUserScriptShouldShowPasswordImportDialog(domain: String, credentials: [SecureVaultModels.WebsiteCredentials], credentialsProvider: SecureVaultModels.CredentialsProvider, totalCredentialsCount: Int) -> Bool {
        guard credentialsProvider.name != .bitwarden else {
            return false
        }
        guard !isBurnerWindow else {
            return false
        }
        guard credentials.isEmpty else {
            return false
        }
        guard totalCredentialsCount < 50 else {
            return false
        }
        guard loginImportStateProvider.shouldShowPasswordImportDialog(for: domain) else {
            return false
        }
        return true
    }
}

private extension AutofillLoginImportStateProvider {
    func shouldShowPasswordImportDialog(for domain: String) -> Bool {
        guard isAutofillEnabled else {
            return false
        }
        guard !hasImportedLogins else {
            return false
        }
        guard isEligibleDDGUser else {
            return false
        }
        guard !hasNeverPromptWebsitesFor(domain) else {
            return false
        }
        guard !isCredentialsImportPromptPermanantlyDismissed else {
            return false
        }
        return true
    }
}
