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
    var emailService: EmailService { get }
    var captchaService: CaptchaService { get }

    var webViewHandler: WebViewHandler? { get set }
    var actionsHandler: ActionsHandler? { get }
    var continuation: CheckedContinuation<ReturnValue, Error>? { get set }
    var extractedProfile: ExtractedProfile? { get set }

    func run(inputValue: InputValue) async throws -> ReturnValue
    func executeNextStep() async
}

extension DataBrokerOperation {

    // MARK: - Shared functions

    func getProfileWithEmail() async throws {

    }

    func runNextAction(_ action: Action) async {
        if let emailConfirmationAction = action as? EmailConfirmationAction {
            try? await runEmailConfirmationAction(action: emailConfirmationAction)
            return
        }

        if action as? SolveCaptchaAction != nil, let captchaTransactionId = actionsHandler?.captchaTransactionId {
            actionsHandler?.captchaTransactionId = nil
            if let captchaData = try? await captchaService.submitCaptchaToBeResolved(for: captchaTransactionId) {
                await webViewHandler?.execute(action: action, profileData: .solveCaptcha(CaptchaToken(token: captchaData)))
            } else {
                onError(error: .captchaServiceError(CaptchaServiceError.nilDataWhenFetchingCaptchaResult))
            }

            return
        }

        if action.needsEmail {
            do {
                extractedProfile?.email = try await emailService.getEmail()
            } catch {
                onError(error: .emailError(error as? EmailError))
                return
            }
        }

        if let extractedProfile = self.extractedProfile {
            await webViewHandler?.execute(action: action, profileData: .extractedProfile(extractedProfile))
        } else {
            await webViewHandler?.execute(action: action, profileData: .profile(query.profileQuery))
        }
    }

    private func runEmailConfirmationAction(action: EmailConfirmationAction) async throws {
        do {
            if let email = extractedProfile?.email {
                let url =  try await emailService.getConfirmationLink(
                    from: email,
                    pollingIntervalInSeconds: action.pollingTime)
                try? await webViewHandler?.load(url: url)
            } else {
                assertionFailure("Trying to run email confirmation without an email.")
                throw EmailError.cantFindEmail
            }
        } catch {
            onError(error: .emailError(error as? EmailError))
        }
    }

    // MARK: - CSSCommunicationDelegate

    func complete(_ value: ReturnValue) {
        self.continuation?.resume(returning: value)
        self.continuation = nil
    }

    func failed(with error: DataBrokerProtectionError) {
        self.continuation?.resume(throwing: error)
        self.continuation = nil
    }

    func initialize() async {
        webViewHandler = await WebViewHandler(privacyConfig: privacyConfig, prefs: prefs, delegate: self)
        await webViewHandler?.initializeWebView()
    }

    func loadURL(url: URL) {
        Task {
            try? await webViewHandler?.load(url: url)
            await executeNextStep()
        }
    }

    func success(actionId: String) {
        Task {
            await executeNextStep()
        }
    }

    func captchaInformation(captchaInfo: GetCaptchaInfoResponse) {
        Task {
            do {
                actionsHandler?.captchaTransactionId = try await captchaService.submitCaptchaInformation(captchaInfo)
                await executeNextStep()
            } catch {
                if let captchaError = error as? CaptchaServiceError {
                    onError(error: DataBrokerProtectionError.captchaServiceError(captchaError))
                } else {
                    onError(error: DataBrokerProtectionError.captchaServiceError(.errorWhenSubmittingCaptcha))
                }
            }
        }
    }

    func onError(error: DataBrokerProtectionError) {
        failed(with: error)

        Task {
            await webViewHandler?.finish()
        }
    }
}
