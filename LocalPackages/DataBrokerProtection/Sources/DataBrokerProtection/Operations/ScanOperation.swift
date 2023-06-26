//
//  ScanOperation.swift
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

public final class ScanOperation: DataBrokerOperation {
    public typealias ReturnValue = [ExtractedProfile]

    public var privacyConfig: PrivacyConfigurationManaging
    public var prefs: ContentScopeProperties
    public var query: BrokerProfileQueryData
    public var webViewHandler: DataBrokerProtectionWebViewHandler?
    public var actionsHandler: DataBrokerProtectionActionsHandler?
    public var continuation: CheckedContinuation<[ExtractedProfile], Error>?

    public init(privacyConfig: PrivacyConfigurationManaging,
                prefs: ContentScopeProperties,
                query: BrokerProfileQueryData) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
    }

    public func run() async throws -> [ExtractedProfile] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task {
                await initialize()

                do {
                    let scanStep = try query.dataBroker.scanStep()
                    actionsHandler = DataBrokerProtectionActionsHandler(step: scanStep)
                    await executeNextStep()
                } catch {
                    failed(with: DataBrokerProtectionError.unknown(error.localizedDescription))
                }
            }
        }
    }

    public func extractedProfiles(profiles: [ExtractedProfile]) {
        complete(profiles)

        Task {
            await executeNextStep()
        }
    }

    public func executeNextStep() async {
        if let action = actionsHandler?.nextAction() {
            await webViewHandler?.execute(action: action, profileData: query.profileQuery)
        } else {
            await webViewHandler?.finish() // If we executed all steps we release the web view
        }
    }
}
