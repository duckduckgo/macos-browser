//
//  OptOutOperation.swift
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
import WebKit
import BrowserServicesKit
import UserScript

final class OptOutOperation: DataBrokerOperation {
    typealias ReturnValue = Void

    let privacyConfig: PrivacyConfigurationManaging
    let prefs: ContentScopeProperties
    let query: BrokerProfileQueryData
    let emailService: EmailService
    let captchaService: CaptchaService
    var webViewHandler: WebViewHandler?
    var actionsHandler: ActionsHandler?
    var continuation: CheckedContinuation<Void, Error>?

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         query: BrokerProfileQueryData,
         emailService: EmailService = EmailService(),
         captchaService: CaptchaService = CaptchaService()
    ) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
        self.emailService = emailService
        self.captchaService = captchaService
    }

    func run() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            Task {
                await initialize()

                do {
                    if let optOutStep = try query.dataBroker.optOutStep() {
                        actionsHandler = ActionsHandler(step: optOutStep)
                        await executeNextStep()
                    } else {
                        // If we try to run an optout on a broker without an optout step, we throw.
                        failed(with: .noOptOutStep)
                    }
                } catch {
                    failed(with: DataBrokerProtectionError.unknown(error.localizedDescription))
                }
            }
        }
    }

    func extractedProfiles(profiles: [ExtractedProfile]) {
        // No - op
    }

    func executeNextStep() async {
        if let action = actionsHandler?.nextAction() {
            await runNextAction(action)
        } else {
            complete(())
            await webViewHandler?.finish() // If we executed all steps we release the web view
        }
    }
}
