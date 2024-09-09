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

final public class AutofillCredentialsImportManager {
    private let userDefaults: UserDefaults

    weak var presentationDelegate: AutofillCredentialsImportPresentationDelegate?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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

    public func autofillUserScriptWillDisplayOverlay(_ serializedInputContext: String) {
        if let data = serializedInputContext.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CredentialsImportInputContext.self, from: data) {
            if decoded.credentialsImport {
                userDefaults.credentialsImportPromptPresentationCount += 1
            }
        }
    }
}
