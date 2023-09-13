//
//  DataBrokerOperation.swift
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

protocol DataBrokerOperation: CCFCommunicationDelegate {
    associatedtype ReturnValue
    associatedtype InputValue

    var privacyConfig: PrivacyConfigurationManaging { get }
    var prefs: ContentScopeProperties { get }
    var query: BrokerProfileQueryData { get }
    var emailService: EmailServiceProtocol { get }
    var captchaService: CaptchaServiceProtocol { get }

    var webViewHandler: WebViewHandler? { get set }
    var actionsHandler: ActionsHandler? { get }
    var continuation: CheckedContinuation<ReturnValue, Error>? { get set }
    var extractedProfile: ExtractedProfile? { get set }

    var shouldRunNextStep: () -> Bool { get }

    func run(inputValue: InputValue,
             webViewHandler: WebViewHandler?,
             actionsHandler: ActionsHandler?,
             showWebView: Bool) async throws -> ReturnValue

    func executeNextStep() async
}

extension DataBrokerOperation {
    func run(inputValue: InputValue,
             webViewHandler: WebViewHandler?,
             actionsHandler: ActionsHandler?,
             shouldRunNextStep: @escaping () -> Bool) async throws -> ReturnValue {

        try await run(inputValue: inputValue,
                      webViewHandler: webViewHandler,
                      actionsHandler: actionsHandler,
                      showWebView: false)
    }
}

extension DataBrokerOperation {

    // MARK: - Shared functions

    func runNextAction(_ action: Action) async {
        if let emailConfirmationAction = action as? EmailConfirmationAction {
            do {
                try await runEmailConfirmationAction(action: emailConfirmationAction)
                await executeNextStep()
            } catch {
                await onError(error: .emailError(error as? EmailError))
            }

            return
        }

        if action as? SolveCaptchaAction != nil, let captchaTransactionId = actionsHandler?.captchaTransactionId {
            actionsHandler?.captchaTransactionId = nil
            if let captchaData = try? await captchaService.submitCaptchaToBeResolved(for: captchaTransactionId,
                                                                                     shouldRunNextStep: shouldRunNextStep) {
                actionsHandler?.captchaToken = captchaData
                await webViewHandler?.execute(action: action, data: .solveCaptcha(CaptchaToken(token: captchaData)))
            } else {
                await onError(error: .captchaServiceError(CaptchaServiceError.nilDataWhenFetchingCaptchaResult))
            }

            return
        }

        if action.needsEmail {
            do {
                extractedProfile?.email = try await emailService.getEmail()
            } catch {
                await onError(error: .emailError(error as? EmailError))
                return
            }
        }

        if let extractedProfile = self.extractedProfile {
            await webViewHandler?.execute(action: action, data: .extractedProfile(extractedProfile))
        } else {
            await webViewHandler?.execute(action: action, data: .profile(query.profileQuery))
        }
    }

    private func runEmailConfirmationAction(action: EmailConfirmationAction) async throws {
        if let email = extractedProfile?.email {
            let url =  try await emailService.getConfirmationLink(
                from: email,
                numberOfRetries: 100, // Move to constant
                pollingIntervalInSeconds: action.pollingTime,
                shouldRunNextStep: shouldRunNextStep
            )
            try? await webViewHandler?.load(url: url)
        } else {
            throw EmailError.cantFindEmail
        }
    }

    func complete(_ value: ReturnValue) {
        self.continuation?.resume(returning: value)
        self.continuation = nil
    }

    func failed(with error: DataBrokerProtectionError) {
        self.continuation?.resume(throwing: error)
        self.continuation = nil
    }

    func initialize(handler: WebViewHandler?,
                    isFakeBroker: Bool = false,
                    showWebView: Bool) async {
        if let handler = handler { // This help us swapping up the WebViewHandler on tests
            self.webViewHandler = handler
        } else {
            self.webViewHandler = await DataBrokerProtectionWebViewHandler(privacyConfig: privacyConfig, prefs: prefs, delegate: self, isFakeBroker: isFakeBroker)
        }

        await webViewHandler?.initializeWebView(showWebView: showWebView)
    }

    // MARK: - CSSCommunicationDelegate

    func loadURL(url: URL) async {
        try? await webViewHandler?.load(url: url)
        await executeNextStep()
    }

    func success(actionId: String, actionType: ActionType) async {
        switch actionType {
        case .click:
            try? await webViewHandler?.waitForWebViewLoad(timeoutInSeconds: 30)
            await executeNextStep()
        default: await executeNextStep()
        }
    }

    func captchaInformation(captchaInfo: GetCaptchaInfoResponse) async {
        do {
            actionsHandler?.captchaTransactionId = try await captchaService.submitCaptchaInformation(captchaInfo,
                                                                                                     shouldRunNextStep: shouldRunNextStep)
            await executeNextStep()
        } catch {
            if let captchaError = error as? CaptchaServiceError {
                await onError(error: DataBrokerProtectionError.captchaServiceError(captchaError))
            } else {
                await onError(error: DataBrokerProtectionError.captchaServiceError(.errorWhenSubmittingCaptcha))
            }
        }
    }

    func solveCaptcha(with response: SolveCaptchaResponse) async {
        do {
            try await webViewHandler?.evaluateJavaScript(response.callback.eval)

            await executeNextStep()
        } catch {
            await onError(error: .solvingCaptchaWithCallbackError)
        }
    }

    func onError(error: DataBrokerProtectionError) async {
        await webViewHandler?.finish()
        failed(with: error)
    }
}
