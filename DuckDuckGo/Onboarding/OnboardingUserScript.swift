//
//  OnboardingUserScript.swift
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
import UserScript
import WebKit

final class OnboardingUserScript: NSObject, Subfeature {

    let onboardingActionsManager: OnboardingActionsManaging
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "onboarding")])
    let featureName: String = "onboarding"
    weak var broker: UserScriptMessageBroker?

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case `init`
        case dismissToSettings
        case dismissToAddressBar
        case requestDockOptIn
        case stepCompleted
        case setBlockCookiePopups
        case setDuckPlayer
        case setBookmarksBar
        case setSessionRestore
        case setShowHomeButton
        case requestAddToDock
        case requestImport
        case requestSetAsDefault
        case reportInitException
        case reportPageException
    }

    init(onboardingActionsManager: OnboardingActionsManaging) {
        self.onboardingActionsManager = onboardingActionsManager
    }

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    private lazy var methodHandlers: [MessageNames: Handler] = [
            .`init`: setInit,
            .dismissToAddressBar: dismissToAddressBar,
            .dismissToSettings: dismissToSettings,
            .requestDockOptIn: requestDockOptIn,
            .requestImport: requestImport,
            .requestSetAsDefault: requestSetAsDefault,
            .setBookmarksBar: setBookmarksBar,
            .setSessionRestore: setSessionRestore,
            .setShowHomeButton: setShowHome,
            .stepCompleted: stepCompleted,
            .reportInitException: reportException,
            .reportPageException: reportException
    ]

    @MainActor
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let messageName = MessageNames(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    // MARK: - UserValuesNotification

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }

}

extension OnboardingUserScript {
    @MainActor
    private func setInit(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        onboardingActionsManager.onboardingStarted()
        return onboardingActionsManager.configuration
    }

    @MainActor
    private func dismissToAddressBar(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        onboardingActionsManager.goToAddressBar()
        return nil
    }

    @MainActor
    private func dismissToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        onboardingActionsManager.goToSettings()
        return nil
    }

    private func requestDockOptIn(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        onboardingActionsManager.addToDock()
        return Result()
    }

    @MainActor
    private func requestImport(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let isDataImported = await onboardingActionsManager.importData()
        return OnboardingImportResponse(enabled: isDataImported)
    }

    private func requestSetAsDefault(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        onboardingActionsManager.setAsDefault()
        return Result()
    }

    @MainActor
    private func setBookmarksBar(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Bool], let enabled = params["enabled"] else { return nil }
        onboardingActionsManager.setBookmarkBar(enabled: enabled)
        return nil
    }

    private func setSessionRestore(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Bool], let enabled = params["enabled"] else { return nil }
        onboardingActionsManager.setSessionRestore(enabled: enabled)
        return nil
    }

    private func setShowHome(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Bool], let enabled = params["enabled"] else { return nil }
        onboardingActionsManager.setHomeButtonPosition(enabled: enabled)
        return nil
    }

    private func stepCompleted(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let params = params as? [String: String], let stepString = params["id"], let step = OnboardingSteps(rawValue: stepString) {
            onboardingActionsManager.stepCompleted(step: step)
        }
        return nil
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: String] else { return nil }
        onboardingActionsManager.reportException(with: params)
        return nil
    }

    struct Result: Encodable {}

}
