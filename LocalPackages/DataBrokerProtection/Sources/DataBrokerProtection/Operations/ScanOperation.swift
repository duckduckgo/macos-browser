//
//  ScanOperation.swift
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

final class ScanOperation: DataBrokerOperation {
    typealias ReturnValue = [ExtractedProfile]
    typealias InputValue = Void

    let privacyConfig: PrivacyConfigurationManaging
    let prefs: ContentScopeProperties
    let query: BrokerProfileQueryData
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol
    var webViewHandler: WebViewHandler?
    var actionsHandler: ActionsHandler?
    var continuation: CheckedContinuation<[ExtractedProfile], Error>?
    var extractedProfile: ExtractedProfile?
    var stageCalculator: DataBrokerProtectionStageDurationCalculator?
    private let operationAwaitTime: TimeInterval
    let shouldRunNextStep: () -> Bool

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         query: BrokerProfileQueryData,
         emailService: EmailServiceProtocol = EmailService(),
         captchaService: CaptchaServiceProtocol = CaptchaService(),
         operationAwaitTime: TimeInterval = 1,
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

    func run(inputValue: Void,
             webViewHandler: WebViewHandler? = nil,
             actionsHandler: ActionsHandler? = nil,
             stageCalculator: DataBrokerProtectionStageDurationCalculator, // We do not need it for scans - for now.
             showWebView: Bool) async throws -> [ExtractedProfile] {
        try await withCheckedThrowingContinuation { continuation in
            self.stageCalculator = stageCalculator
            self.continuation = continuation
            Task {
                await initialize(handler: webViewHandler, isFakeBroker: query.dataBroker.isFakeBroker, showWebView: showWebView)

                do {
                    let scanStep = try query.dataBroker.scanStep()
                    if let actionsHandler = actionsHandler {
                        self.actionsHandler = actionsHandler
                    } else {
                        self.actionsHandler = ActionsHandler(step: scanStep)
                    }
                    if self.shouldRunNextStep() {
                        await executeNextStep()
                    } else {
                        failed(with: DataBrokerProtectionError.cancelled)
                    }
                } catch {
                    failed(with: DataBrokerProtectionError.unknown(error.localizedDescription))
                }
            }
        }
    }

    func extractedProfiles(profiles: [ExtractedProfile]) async {
        complete(profiles)
        await executeNextStep()
    }

    func executeNextStep() async {
        os_log("SCAN Waiting %{public}f seconds...", log: .action, operationAwaitTime)

        try? await Task.sleep(nanoseconds: UInt64(operationAwaitTime) * 1_000_000_000)

        if let action = actionsHandler?.nextAction() {
            os_log("Next action: %{public}@", log: .action, String(describing: action.actionType.rawValue))
            await runNextAction(action)
        } else {
            os_log("Releasing the web view", log: .action)
            await webViewHandler?.finish() // If we executed all steps we release the web view
        }
    }
}
