//
//  OnboardingUserScript.swift
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

import BrowserServicesKit
import Configuration
import WebKit
import Common
import UserScript

final class OnboardingUserScript: NSObject, Subfeature {

    let messageOriginPolicy: MessageOriginPolicy = .all
    let featureName: String = "onboarding"
    var broker: UserScriptMessageBroker?

    // MARK: - Subfeature
    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case setBlockCookiePopups
        case setDuckPlayer
        case setBookmarksBar
        case setSessionRestore
        case setShowHomeButton
        case requestAddToDock
        case requestImport
        case requestSetAsDefault
        case dismiss
        case dismissToSettings
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .setDuckPlayer:
            return setDuckPlayer
        case .setBookmarksBar:
            return setBookmarksBar
        case .setSessionRestore:
            return setSessionRestore
        case .setShowHomeButton:
            return setShowHome
        case .requestImport:
            return requestImport
        case .requestSetAsDefault:
            return requestSetAsDefault
        default:
            print(methodName)
            //            assertionFailure("PrivacyConfigurationEditUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    @MainActor
    func setDuckPlayer(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DuckPlayerPreferences.shared.duckPlayerMode = .enabled
        return nil
    }

    @MainActor
    func setBookmarksBar(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        AppearancePreferences.shared.showBookmarksBar = true
        return nil
    }

    @MainActor
    func setSessionRestore(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        StartupPreferences.shared.restorePreviousSession = true
        return nil
    }

    @MainActor
    func setShowHome(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        StartupPreferences.shared.homeButtonPosition = .left
        StartupPreferences.shared.updateHomeButton()
        return nil
    }

    @MainActor
    func requestImport(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DataImportViewController.show()
        return nil
    }

    @MainActor
    func requestSetAsDefault(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let defaultBrowserPreferences = DefaultBrowserPreferences()
        if defaultBrowserPreferences.isDefault {
            //                completion()
            //                return
        }

        defaultBrowserPreferences.becomeDefault { _ in
            _ = defaultBrowserPreferences
            //                withAnimation {
            //                    completion()
            //                }
        }
        return nil
    }

}
