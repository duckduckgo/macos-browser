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
import Common

final class OptOutOperation: DataBrokerOperation {
    typealias ReturnValue = Void
    typealias InputValue = ExtractedProfile

    let privacyConfig: PrivacyConfigurationManaging
    let prefs: ContentScopeProperties
    let query: BrokerProfileQueryData
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol
    var webViewHandler: WebViewHandler?
    var actionsHandler: ActionsHandler?
    var continuation: CheckedContinuation<Void, Error>?
    var extractedProfile: ExtractedProfile?
    var stageCalculator: DataBrokerProtectionStageDurationCalculator?
    private let operationAwaitTime: TimeInterval
    let shouldRunNextStep: () -> Bool
    var retriesCountOnError: Int = 0

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         query: BrokerProfileQueryData,
         emailService: EmailServiceProtocol = EmailService(),
         captchaService: CaptchaServiceProtocol = CaptchaService(),
         operationAwaitTime: TimeInterval = 3,
         shouldRunNextStep: @escaping () -> Bool
    ) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
        self.emailService = emailService
        self.captchaService = captchaService
        self.operationAwaitTime = operationAwaitTime
        self.shouldRunNextStep = shouldRunNextStep
    }

    func run(inputValue: ExtractedProfile,
             webViewHandler: WebViewHandler? = nil,
             actionsHandler: ActionsHandler? = nil,
             stageCalculator: DataBrokerProtectionStageDurationCalculator,
             showWebView: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.extractedProfile = inputValue.merge(with: query.profileQuery)
            self.stageCalculator = stageCalculator
            self.continuation = continuation

            Task {
                await initialize(handler: webViewHandler,
                                 isFakeBroker: query.dataBroker.isFakeBroker,
                                 showWebView: showWebView)

                if let optOutStep = query.dataBroker.optOutStep() {
                    if let actionsHandler = actionsHandler {
                        self.actionsHandler = actionsHandler
                    } else {
                        self.actionsHandler = ActionsHandler(step: optOutStep)
                    }

                    if self.shouldRunNextStep() {
                        await executeNextStep()
                    } else {
                        failed(with: DataBrokerProtectionError.cancelled)
                    }

                } else {
                    // If we try to run an optout on a broker without an optout step, we throw.
                    failed(with: .noOptOutStep)
                }
            }
        }
    }

    func extractedProfiles(profiles: [ExtractedProfile]) async {
        // No - op
    }

    func executeNextStep() async {
        retriesCountOnError = 0 // We reset the retries on error when it is successful
        os_log("OPTOUT Waiting %{public}f seconds...", log: .action, operationAwaitTime)
        try? await Task.sleep(nanoseconds: UInt64(operationAwaitTime) * 1_000_000_000)

        if let action = actionsHandler?.nextAction(), self.shouldRunNextStep() {
            await runNextAction(action)
        } else {
            await webViewHandler?.finish() // If we executed all steps we release the web view
            stageCalculator?.fireOptOutValidate()
            stageCalculator?.fireOptOutSubmitSuccess()
            complete(())
        }
    }
}
