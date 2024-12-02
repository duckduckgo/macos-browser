//
//  ScanJob.swift
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
import os.log

final class ScanJob: DataBrokerJob {
    typealias ReturnValue = [ExtractedProfile]
    typealias InputValue = Void

    let privacyConfig: PrivacyConfigurationManaging
    let prefs: ContentScopeProperties
    let query: BrokerProfileQueryData
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol
    let cookieHandler: CookieHandler
    let stageCalculator: StageDurationCalculator
    var webViewHandler: WebViewHandler?
    var actionsHandler: ActionsHandler?
    var continuation: CheckedContinuation<[ExtractedProfile], Error>?
    var extractedProfile: ExtractedProfile?
    private let operationAwaitTime: TimeInterval
    let shouldRunNextStep: () -> Bool
    var retriesCountOnError: Int = 0
    let clickAwaitTime: TimeInterval
    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    var postLoadingSiteStartTime: Date?
    let sleepObserver: SleepObserver

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         query: BrokerProfileQueryData,
         emailService: EmailServiceProtocol,
         captchaService: CaptchaServiceProtocol,
         cookieHandler: CookieHandler = BrokerCookieHandler(),
         operationAwaitTime: TimeInterval = 3,
         clickAwaitTime: TimeInterval = 0,
         stageDurationCalculator: StageDurationCalculator,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         sleepObserver: SleepObserver,
         shouldRunNextStep: @escaping () -> Bool
    ) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
        self.emailService = emailService
        self.captchaService = captchaService
        self.operationAwaitTime = operationAwaitTime
        self.stageCalculator = stageDurationCalculator
        self.shouldRunNextStep = shouldRunNextStep
        self.clickAwaitTime = clickAwaitTime
        self.cookieHandler = cookieHandler
        self.pixelHandler = pixelHandler
        self.sleepObserver = sleepObserver
    }

    func run(inputValue: InputValue,
             webViewHandler: WebViewHandler? = nil,
             actionsHandler: ActionsHandler? = nil,
             showWebView: Bool) async throws -> [ExtractedProfile] {
        try await withCheckedThrowingContinuation { continuation in
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

    func extractedProfiles(profiles: [ExtractedProfile], meta: [String: Any]?) async {
        complete(profiles)
        await executeNextStep()
    }

    func executeNextStep() async {
        retriesCountOnError = 0 // We reset the retries on error when it is successful
        Logger.action.debug("SCAN Waiting \(self.operationAwaitTime, privacy: .public) seconds...")

        try? await Task.sleep(nanoseconds: UInt64(operationAwaitTime) * 1_000_000_000)

        if let action = actionsHandler?.nextAction() {
            Logger.action.debug("Next action: \(String(describing: action.actionType.rawValue), privacy: .public)")
            await runNextAction(action)
        } else {
            Logger.action.debug("Releasing the web view")
            await webViewHandler?.finish() // If we executed all steps we release the web view
        }
    }
}
