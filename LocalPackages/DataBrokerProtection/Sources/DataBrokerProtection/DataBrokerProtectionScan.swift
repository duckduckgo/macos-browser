//
//  DataBrokerProtectionScan.swift
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

protocol DataBrokerProtectionScanOperation {
    func scan(dataBrokerData: DataBrokerData, profileData: ProfileData) async throws -> [ExtractedProfile]
}

public class DataBrokerProtectionScan: DataBrokerProtectionScanOperation {
    private let privacyConfig: PrivacyConfigurationManaging
    private let prefs: ContentScopeProperties

    private var scanActiveContinuation: CheckedContinuation<[ExtractedProfile], Error>?
    private var handler: DataBrokerProtectionWebViewHandler?
    private var profileData: ProfileData?
    private var actionsHandler: DataBrokerProtectionActionsHandler?

    public init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
    }

    public func scan(dataBrokerData: DataBrokerData, profileData: ProfileData) async throws -> [ExtractedProfile] {
        try await withCheckedThrowingContinuation { continuation in
            self.scanActiveContinuation = continuation
            self.profileData = profileData

            Task {
                await self.initialize(dataBrokerData: dataBrokerData, profileData: profileData)
            }
        }
    }

    private func initialize(dataBrokerData: DataBrokerData, profileData: ProfileData) async {
        handler = await DataBrokerProtectionWebViewHandler(privacyConfig: privacyConfig, prefs: prefs, delegate: self)
        await handler?.initializeWebView()

        do {
            let scanStep = try dataBrokerData.scanStep()
            actionsHandler = DataBrokerProtectionActionsHandler(step: scanStep)
            await executeNextStep()
        } catch {
            scanActiveContinuation?.resume(throwing: error)
        }
    }

    private func executeNextStep() async {
        if let action = actionsHandler?.nextAction(), let profileData = self.profileData {
            await handler?.execute(action: action, profileData: profileData)
        } else {
            await handler?.finish() // If we executed all steps we release the web view
        }
    }
}

extension DataBrokerProtectionScan: CSSCommunicationDelegate {

    func loadURL(url: URL) {
        Task {
            try? await handler?.load(url: url)
            await executeNextStep()
        }
    }

    func extractedProfiles(profiles: [ExtractedProfile]) {
        scanActiveContinuation?.resume(returning: profiles)
        Task {
            await executeNextStep()
        }
    }

    func onError(error: DataBrokerProtectionError) {
        scanActiveContinuation?.resume(throwing: error)
        Task {
            await handler?.finish()
        }
    }
}
