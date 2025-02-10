//
//  DataBrokerJob.swift
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

protocol DataBrokerJob: CCFCommunicationDelegate {
    associatedtype ReturnValue
    associatedtype InputValue

    var privacyConfig: PrivacyConfigurationManaging { get }
    var prefs: ContentScopeProperties { get }
    var query: BrokerProfileQueryData { get }
    var emailService: EmailServiceProtocol { get }
    var captchaService: CaptchaServiceProtocol { get }
    var cookieHandler: CookieHandler { get }
    var stageCalculator: StageDurationCalculator { get }
    var pixelHandler: EventMapping<DataBrokerProtectionPixels> { get }
    var sleepObserver: SleepObserver { get }

    var webViewHandler: WebViewHandler? { get set }
    var actionsHandler: ActionsHandler? { get }
    var continuation: CheckedContinuation<ReturnValue, Error>? { get set }
    var extractedProfile: ExtractedProfile? { get set }
    var shouldRunNextStep: () -> Bool { get }
    var retriesCountOnError: Int { get set }
    var clickAwaitTime: TimeInterval { get }
    var postLoadingSiteStartTime: Date? { get set }

    func run(inputValue: InputValue,
             webViewHandler: WebViewHandler?,
             actionsHandler: ActionsHandler?,
             showWebView: Bool) async throws -> ReturnValue

    func executeNextStep() async
    func executeCurrentAction() async
}

extension DataBrokerJob {
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

extension DataBrokerJob {

    // MARK: - Shared functions

    func runNextAction(_ action: Action) async {
        switch action {
        case is GetCaptchaInfoAction:
            stageCalculator.setStage(.captchaParse)
        case is ClickAction:
            stageCalculator.setStage(.fillForm)
        case is FillFormAction:
            stageCalculator.setStage(.fillForm)
        case is ExpectationAction:
            stageCalculator.setStage(.submit)
        default: ()
        }

        if let emailConfirmationAction = action as? EmailConfirmationAction {
            do {
                stageCalculator.fireOptOutSubmit()
                try await runEmailConfirmationAction(action: emailConfirmationAction)
                await executeNextStep()
            } catch {
                await onError(error: DataBrokerProtectionError.emailError(error as? EmailError))
            }

            return
        }

        if action as? SolveCaptchaAction != nil, let captchaTransactionId = actionsHandler?.captchaTransactionId {
            actionsHandler?.captchaTransactionId = nil
            stageCalculator.setStage(.captchaSolve)
            if let captchaData = try? await captchaService.submitCaptchaToBeResolved(for: captchaTransactionId,
                                                                                     attemptId: stageCalculator.attemptId,
                                                                                     shouldRunNextStep: shouldRunNextStep) {
                stageCalculator.fireOptOutCaptchaSolve()
                await webViewHandler?.execute(action: action, data: .solveCaptcha(CaptchaToken(token: captchaData)))
            } else {
                await onError(error: DataBrokerProtectionError.captchaServiceError(CaptchaServiceError.nilDataWhenFetchingCaptchaResult))
            }

            return
        }

        if action.needsEmail {
            do {
                stageCalculator.setStage(.emailGenerate)
                let emailData = try await emailService.getEmail(dataBrokerURL: query.dataBroker.url, attemptId: stageCalculator.attemptId)
                extractedProfile?.email = emailData.emailAddress
                stageCalculator.setEmailPattern(emailData.pattern)
                stageCalculator.fireOptOutEmailGenerate()
            } catch {
                await onError(error: DataBrokerProtectionError.emailError(error as? EmailError))
                return
            }
        }

        await webViewHandler?.execute(action: action, data: .userData(query.profileQuery, self.extractedProfile))
    }

    private func runEmailConfirmationAction(action: EmailConfirmationAction) async throws {
        if let email = extractedProfile?.email {
            stageCalculator.setStage(.emailReceive)
            let url =  try await emailService.getConfirmationLink(
                from: email,
                numberOfRetries: 100, // Move to constant
                pollingInterval: action.pollingTime,
                attemptId: stageCalculator.attemptId,
                shouldRunNextStep: shouldRunNextStep
            )
            stageCalculator.fireOptOutEmailReceive()
            stageCalculator.setStage(.emailReceive)
            do {
                try await webViewHandler?.load(url: url)
            } catch {
                await onError(error: error)
                return
            }

            stageCalculator.fireOptOutEmailConfirm()
        } else {
            throw EmailError.cantFindEmail
        }
    }

    func complete(_ value: ReturnValue) {
        self.firePostLoadingDurationPixel(hasError: false)
        self.continuation?.resume(returning: value)
        self.continuation = nil
    }

    func failed(with error: Error) {
        self.firePostLoadingDurationPixel(hasError: true)
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
        let webSiteStartLoadingTime = Date()

        do {
            // https://app.asana.com/0/1204167627774280/1206912494469284/f
            if query.dataBroker.url == "spokeo.com" {
                if let cookies = await cookieHandler.getAllCookiesFromDomain(url) {
                    await webViewHandler?.setCookies(cookies)
                }
            }

            let successNextSteps = {
                self.fireSiteLoadingPixel(startTime: webSiteStartLoadingTime, hasError: false)
                self.postLoadingSiteStartTime = Date()
                await self.executeNextStep()
            }

            /* When the job is a `ScanJob` and the error is `404`, we want to continue
                executing steps and respect the C-S-S result
             */
            let error404 = DataBrokerProtectionError.httpError(code: 404)

            do  {
                try await webViewHandler?.load(url: url)
                await successNextSteps()
            } catch let error as DataBrokerProtectionError {
                guard error == error404 && self is ScanJob else {
                    throw error
                }

                await successNextSteps()
            }

        } catch {
            fireSiteLoadingPixel(startTime: webSiteStartLoadingTime, hasError: true)
            await onError(error: error)
        }
    }

    private func fireSiteLoadingPixel(startTime: Date, hasError: Bool) {
        if stageCalculator.isImmediateOperation {
            let dataBrokerURL = self.query.dataBroker.url
            let durationInMs = (Date().timeIntervalSince(startTime) * 1000).rounded(.towardZero)
            pixelHandler.fire(.initialScanSiteLoadDuration(duration: durationInMs, hasError: hasError, brokerURL: dataBrokerURL, sleepDuration: sleepObserver.totalSleepTime()))
        }
    }

    func firePostLoadingDurationPixel(hasError: Bool) {
        if stageCalculator.isImmediateOperation, let postLoadingSiteStartTime = self.postLoadingSiteStartTime {
            let dataBrokerURL = self.query.dataBroker.url
            let durationInMs = (Date().timeIntervalSince(postLoadingSiteStartTime) * 1000).rounded(.towardZero)
            pixelHandler.fire(.initialScanPostLoadingDuration(duration: durationInMs, hasError: hasError, brokerURL: dataBrokerURL, sleepDuration: sleepObserver.totalSleepTime()))
        }
    }

    func success(actionId: String, actionType: ActionType) async {
        switch actionType {
        case .click:
            stageCalculator.fireOptOutFillForm()
            // We wait 40 seconds before tapping
            try? await Task.sleep(nanoseconds: UInt64(clickAwaitTime) * 1_000_000_000)
            await executeNextStep()
        case .fillForm:
            stageCalculator.fireOptOutFillForm()
            await executeNextStep()
        default: await executeNextStep()
        }
    }

    func captchaInformation(captchaInfo: GetCaptchaInfoResponse) async {
        do {
            stageCalculator.fireOptOutCaptchaParse()
            stageCalculator.setStage(.captchaSend)
            actionsHandler?.captchaTransactionId = try await captchaService.submitCaptchaInformation(
                captchaInfo,
                attemptId: stageCalculator.attemptId,
                shouldRunNextStep: shouldRunNextStep)
            stageCalculator.fireOptOutCaptchaSend()
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
            await onError(error: DataBrokerProtectionError.solvingCaptchaWithCallbackError)
        }
    }

    func onError(error: Error) async {
        if retriesCountOnError > 0 {
            await executeCurrentAction()
        } else {
            await webViewHandler?.finish()
            failed(with: error)
        }
    }

    func executeCurrentAction() async {
        let waitTimeUntilRunningTheActionAgain: TimeInterval = 3
        try? await Task.sleep(nanoseconds: UInt64(waitTimeUntilRunningTheActionAgain) * 1_000_000_000)

        if let currentAction = self.actionsHandler?.currentAction() {
            retriesCountOnError -= 1
            await runNextAction(currentAction)
        } else {
            retriesCountOnError = 0
            await onError(error: DataBrokerProtectionError.unknown("No current action to execute"))
        }
    }
}

protocol CookieHandler {
    func getAllCookiesFromDomain(_ url: URL) async -> [HTTPCookie]?
}

struct BrokerCookieHandler: CookieHandler {

    func getAllCookiesFromDomain(_ url: URL) async -> [HTTPCookie]? {
        guard let domainURL = extractSchemeAndHostAsURL(from: url.absoluteString) else { return nil }
        do {
            let (_, response) = try await URLSession.shared.data(from: domainURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  let allHeaderFields = httpResponse.allHeaderFields as? [String: String] else { return nil }

            let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: domainURL)
            return cookies
        } catch {
            print("Error fetching data: \(error)")
        }

        return nil
    }

    private func extractSchemeAndHostAsURL(from url: String) -> URL? {
        if let urlComponents = URLComponents(string: url), let scheme = urlComponents.scheme, let host = urlComponents.host {
            return URL(string: "\(scheme)://\(host)")
        }
        return nil
    }
}
