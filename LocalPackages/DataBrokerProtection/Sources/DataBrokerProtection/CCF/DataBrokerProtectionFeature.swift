//
//  DataBrokerProtectionFeature.swift
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
import os.log

protocol CCFCommunicationDelegate: AnyObject {
    func loadURL(url: URL) async
    func extractedProfiles(profiles: [ExtractedProfile], meta: [String: Any]?) async
    func captchaInformation(captchaInfo: GetCaptchaInfoResponse) async
    func solveCaptcha(with response: SolveCaptchaResponse) async
    func success(actionId: String, actionType: ActionType) async
    func onError(error: Error) async
}

enum CCFSubscribeActionName: String {
    case onActionReceived
}

enum CCFReceivedMethodName: String {
    case actionCompleted
    case actionError
}

struct DataBrokerProtectionFeature: Subfeature {
    var messageOriginPolicy: MessageOriginPolicy = .all
    var featureName: String = "brokerProtection"
    weak var broker: UserScriptMessageBroker? // This broker is not related to DBP brokers. It's just a name we inherit from Subfeature

    weak var delegate: CCFCommunicationDelegate?

    init(delegate: CCFCommunicationDelegate) {
        self.delegate = delegate
    }

    func handler(forMethodNamed methodName: String) -> Handler? {
        let actionResult = CCFReceivedMethodName(rawValue: methodName)

        if let actionResult = actionResult {
            switch actionResult {
            case .actionCompleted: return onActionCompleted
            case .actionError: return onActionError
            }
        } else {
            Logger.action.log("Cant parse method: \(methodName, privacy: .public)")
            return nil
        }
    }

    func onActionCompleted(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        Logger.action.log("Action completed")

        await parseActionCompleted(params: params)
        return nil
    }

    func parseActionCompleted(params: Any) async {
        Logger.action.log("Parse action completed")

        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(CCFResult.self, from: data) else {
            await delegate?.onError(error: DataBrokerProtectionError.parsingErrorObjectFailed)
            return
        }

        switch result.result {
        case .success(let successResponse):
            await parseSuccess(success: successResponse)
        case .error(let error):
            let dataBrokerError: DataBrokerProtectionError = .actionFailed(actionID: error.actionID, message: error.message)
            await delegate?.onError(error: dataBrokerError)
        }
    }

    func parseSuccess(success: CCFSuccessResponse) async {
        Logger.action.log("Parse success: \(String(describing: success.actionType.rawValue), privacy: .public)")

        switch success.response {
        case .navigate(let navigate):
            if let url = URL(string: navigate.url) {
                await delegate?.loadURL(url: url)
            } else {
                await delegate?.onError(error: DataBrokerProtectionError.malformedURL)
            }
        case .extract(let profiles):
            await delegate?.extractedProfiles(profiles: profiles, meta: success.meta)
        case .getCaptchaInfo(let captchaInfo):
            await delegate?.captchaInformation(captchaInfo: captchaInfo)
        case .solveCaptcha(let response):
            await delegate?.solveCaptcha(with: response)
        case .fillForm, .click, .expectation:
            await delegate?.success(actionId: success.actionID, actionType: success.actionType)
        default: return
        }
    }

    func onActionError(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let error = DataBrokerProtectionError.parse(params: params)
        Logger.action.log("Action Error: \(String(describing: error.localizedDescription), privacy: .public)")

        await delegate?.onError(error: error)
        return nil
    }

    mutating func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    func pushAction(method: CCFSubscribeActionName, webView: WKWebView, params: Encodable) {
        guard let broker = broker else {
            assertionFailure("Cannot continue without broker instance")
            return
        }
        Logger.action.log("Pushing into WebView: \(method.rawValue) params \(String(describing: params))")

        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }
}
