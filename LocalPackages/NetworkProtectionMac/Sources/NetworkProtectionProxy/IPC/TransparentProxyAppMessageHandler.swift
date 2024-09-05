//
//  TransparentProxyAppMessageHandler.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import os.log
import NetworkExtension

/// Handles app messages
///
final class TransparentProxyAppMessageHandler {

    private let settings: TransparentProxySettings
    private let logger: Logger

    init(settings: TransparentProxySettings, logger: Logger) {

        self.logger = logger
        self.settings = settings
    }

    func handle(_ data: Data) async -> Data? {
        do {
            let message = try JSONDecoder().decode(TransparentProxyMessage.self, from: data)
            return await handle(message)
        } catch {
            return nil
        }
    }

    /// Handles a message.
    ///
    /// This method will wrap the message into a request with a completion handler, and will process it.
    /// The reason why this method wraps the message in a request is to ensure that the response
    /// type stays syncrhonized between app and provider.
    ///
    private func handle(_ message: TransparentProxyMessage) async -> Data? {
        await withCheckedContinuation { continuation in
            var request: TransparentProxyRequest

            logger.log("Handling app message: \(String(describing: message), privacy: .public)")

            switch message {
            case .changeSetting(let change):
                request = .changeSetting(change) {
                    continuation.resume(returning: nil)
                }
            }

            handle(request)
        }
    }

    /// Handles a request and calls the response handler when done.
    ///
    private func handle(_ request: TransparentProxyRequest) {
        switch request {
        case .changeSetting(let change, let responseHandler):
            handle(change)
            responseHandler()
        }
    }

    /// Handles a settings change.
    ///
    private func handle(_ settingChange: TransparentProxySettings.Change) {
        switch settingChange {
        case .appRoutingRules(let routingRules):
            settings.appRoutingRules = routingRules
        case .excludedDomains(let excludedDomains):
            settings.excludedDomains = excludedDomains
        }
    }
}
