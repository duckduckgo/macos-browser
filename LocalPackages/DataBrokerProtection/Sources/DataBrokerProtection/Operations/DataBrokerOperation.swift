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

public protocol DataBrokerOperation: CSSCommunicationDelegate {
    associatedtype ReturnValue
    var privacyConfig: PrivacyConfigurationManaging { get }
    var prefs: ContentScopeProperties { get }
    var query: BrokerProfileQueryData { get }
    var emailService: DataBrokerProtectionEmailService { get }
    var captchaService: DataBrokerProtectionCaptchaService { get }

    var webViewHandler: DataBrokerProtectionWebViewHandler? { get set }
    var actionsHandler: DataBrokerProtectionActionsHandler? { get }
    var continuation: CheckedContinuation<ReturnValue, Error>? { get set }

    func run() async throws -> ReturnValue
    func executeNextStep() async
}

public extension DataBrokerOperation {

    // MARK: - Shared functions

    func getProfileWithEmail() async throws -> ProfileQuery {
        let email = try await emailService.getEmail()
        return query.profileQuery.copy(email: email)
    }

    func runNextAction(_ action: Action) async {
        if let emailConfirmationAction = action as? EmailConfirmationAction {
            try? await runEmailConfirmationAction(action: emailConfirmationAction)
            return
        }

        if action.needsEmail {
            do {
                query.profileQuery = try await getProfileWithEmail()
            } catch {
                onError(error: .emailError(error as? DataBrokerProtectionEmailService.EmailError))
                return
            }
        }

        await webViewHandler?.execute(action: action, profileData: query.profileQuery)
    }

    private func runEmailConfirmationAction(action: EmailConfirmationAction) async throws {
        do {
            if let email = query.profileQuery.email {
                let url =  try await emailService.getConfirmationLink(
                    from: email,
                    pollingIntervalInSeconds: action.pollingTime)
                try? await webViewHandler?.load(url: url)
            } else {
                assertionFailure("Trying to run email confirmation without an email.")
                throw DataBrokerProtectionEmailService.EmailError.cantFindEmail
            }
        } catch {
            onError(error: .emailError(error as? DataBrokerProtectionEmailService.EmailError))
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
        webViewHandler = await DataBrokerProtectionWebViewHandler(privacyConfig: privacyConfig, prefs: prefs, delegate: self)
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
                let captchaTransactonId = try await captchaService.submitCaptchaInformation(captchaInfo)
                print(captchaTransactonId)
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
