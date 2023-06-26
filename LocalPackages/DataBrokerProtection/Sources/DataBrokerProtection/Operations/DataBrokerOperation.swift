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

    var webViewHandler: DataBrokerProtectionWebViewHandler? { get set }
    var actionsHandler: DataBrokerProtectionActionsHandler? { get }
    var continuation: CheckedContinuation<ReturnValue, Error>? { get set }

    func run() async throws -> ReturnValue
    func executeNextStep() async
}

public extension DataBrokerOperation {
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

    func onError(error: DataBrokerProtectionError) {
        failed(with: error)

        Task {
            await webViewHandler?.finish()
        }
    }
}
