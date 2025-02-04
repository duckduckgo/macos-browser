//
//  DebugScanJob.swift
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

struct DebugScanReturnValue {
    let brokerURL: String
    let extractedProfiles: [ExtractedProfile]
    let error: Error?
    let brokerProfileQueryData: BrokerProfileQueryData
    let meta: [String: Any]?

    init(brokerURL: String,
         extractedProfiles: [ExtractedProfile] = [ExtractedProfile](),
         error: Error? = nil,
         brokerProfileQueryData: BrokerProfileQueryData,
         meta: [String: Any]? = nil) {
        self.brokerURL = brokerURL
        self.extractedProfiles = extractedProfiles
        self.error = error
        self.brokerProfileQueryData = brokerProfileQueryData
        self.meta = meta
    }
}

struct EmptyCookieHandler: CookieHandler {
    func getAllCookiesFromDomain(_ url: URL) async -> [HTTPCookie]? {
        return nil
    }
}

final class DebugScanJob: DataBrokerJob {
    typealias ReturnValue = DebugScanReturnValue
    typealias InputValue = Void

    let privacyConfig: PrivacyConfigurationManaging
    let prefs: ContentScopeProperties
    let query: BrokerProfileQueryData
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol
    let stageCalculator: StageDurationCalculator
    var webViewHandler: WebViewHandler?
    var actionsHandler: ActionsHandler?
    var continuation: CheckedContinuation<DebugScanReturnValue, Error>?
    var extractedProfile: ExtractedProfile?
    private let operationAwaitTime: TimeInterval
    let shouldRunNextStep: () -> Bool
    var retriesCountOnError: Int = 0
    var scanURL: String?
    let clickAwaitTime: TimeInterval
    let cookieHandler: CookieHandler
    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    var postLoadingSiteStartTime: Date?
    let sleepObserver: SleepObserver

    private let fileManager = FileManager.default
    private let debugScanContentPath: String?

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         query: BrokerProfileQueryData,
         emailService: EmailServiceProtocol,
         captchaService: CaptchaServiceProtocol,
         operationAwaitTime: TimeInterval = 3,
         clickAwaitTime: TimeInterval = 0,
         shouldRunNextStep: @escaping () -> Bool
    ) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
        self.emailService = emailService
        self.captchaService = captchaService
        self.operationAwaitTime = operationAwaitTime
        self.shouldRunNextStep = shouldRunNextStep
        self.clickAwaitTime = clickAwaitTime
        if let desktopPath = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first?.relativePath {
            self.debugScanContentPath = desktopPath + "/PIR-Debug"
        } else {
            self.debugScanContentPath = nil
        }
        self.cookieHandler = EmptyCookieHandler()
        stageCalculator = FakeStageDurationCalculator()
        pixelHandler =  EventMapping(mapping: { _, _, _, _ in
            // We do not need the pixel handler for the debug
        })
        self.sleepObserver = FakeSleepObserver()
    }

    func run(inputValue: Void,
             webViewHandler: WebViewHandler? = nil,
             actionsHandler: ActionsHandler? = nil,
             showWebView: Bool) async throws -> DebugScanReturnValue {
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

    func runNextAction(_ action: Action) async {
        if action as? ExtractAction != nil {
            do {
                if let path = self.debugScanContentPath {
                    let fileName = "\(query.profileQuery.id ?? 0)_\(query.dataBroker.name)"
                    try await webViewHandler?.takeSnaphost(path: path + "/screenshots/", fileName: "\(fileName).png")
                    try await webViewHandler?.saveHTML(path: path + "/html/", fileName: "\(fileName).html")
                }
            } catch {
                print("Error: \(error)")
            }
        }

        await webViewHandler?.execute(action: action, data: .userData(query.profileQuery, self.extractedProfile))
    }

    func extractedProfiles(profiles: [ExtractedProfile], meta: [String: Any]?) async {
        if let scanURL = self.scanURL {
            let debugScanReturnValue = DebugScanReturnValue(
                brokerURL: scanURL,
                extractedProfiles: profiles,
                brokerProfileQueryData: query,
                meta: meta
            )
            complete(debugScanReturnValue)
        }

        await executeNextStep()
    }

    func completeWith(error: Error) async {
        if let scanURL = self.scanURL {
            let debugScanReturnValue = DebugScanReturnValue(brokerURL: scanURL, error: error, brokerProfileQueryData: query)
            complete(debugScanReturnValue)
        }

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
            continuation = nil
            webViewHandler = nil
        }
    }

    func loadURL(url: URL) async {
        do {
            self.scanURL = url.absoluteString
            try await webViewHandler?.load(url: url)
            await executeNextStep()
        } catch {
            await completeWith(error: error)
        }
    }

    deinit {
        Logger.action.debug("DebugScanOperation Deinit")
    }
}
