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

protocol CSSCommunicationDelegate: AnyObject {
    func loadURL(url: URL)
    func extractedProfiles(profiles: [ExtractedProfile])
    func onError(error: DataBrokerProtectionError)
}

enum CSSSubscribeActionName: String {
    case onActionReceived
}

enum CSSReceivedMethodName: String {
    case actionCompleted
    case actionError
}

struct DataBrokerProtectionFeature: Subfeature {
    var messageOriginPolicy: MessageOriginPolicy = .all
    var featureName: String = "brokerProtection"
    var broker: UserScriptMessageBroker?

    weak var delegate: CSSCommunicationDelegate?

    init(delegate: CSSCommunicationDelegate) {
        self.delegate = delegate
    }

    func handler(forMethodNamed methodName: String) -> Handler? {
        let actionResult = CSSReceivedMethodName(rawValue: methodName)

        if let actionResult = actionResult {
            switch actionResult {
            case .actionCompleted: return onActionCompleted
            case .actionError: return onActionError
            }
        } else {
            // Send Pixel to check the method that was not parsed correctly.
            return nil
        }
    }

    func onActionCompleted(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        parseActionCompleted(params: params)
        return nil
    }

    func parseActionCompleted(params: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(CSSResult.self, from: data) else {
            delegate?.onError(error: .parsingErrorObjectFailed)
            return
        }

        switch result.result {
        case .success(let successResponse):
            parseSuccess(success: successResponse)
        case .error(let error):
            let dataBrokerError: DataBrokerProtectionError = .actionFailed(actionID: error.actionID, message: error.message)
            delegate?.onError(error: dataBrokerError)
        }
    }

    func parseSuccess(success: CSSSuccessResponse) {
        switch success.response {
        case .navigate(let navigate):
            if let url = URL(string: navigate.url) {
                delegate?.loadURL(url: url)
            } else {
                delegate?.onError(error: .malformedURL)
            }
        case .extract(let profiles):
            delegate?.extractedProfiles(profiles: profiles)
        default: return
        }
    }

    func onActionError(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let error = DataBrokerProtectionError.parse(params: params)
        delegate?.onError(error: error)
        return nil
    }

    mutating func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    func pushAction(method: CSSSubscribeActionName, webView: WKWebView, params: Encodable) {
        guard let broker = broker else {
            delegate?.onError(error: .userScriptMessageBrokerNotSet)
            assertionFailure("Cannot continue without broker instance")
            return
        }

        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }
}
