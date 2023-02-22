//
//  FBProtectionTabExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine
import Foundation
import Navigation
import UserScript

final class FBProtectionTabExtension {

    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private weak var userContentController: UserContentControllerProtocol?

    private var cancellables = Set<AnyCancellable>()

    var fbBlockingEnabled = true

    init(privacyConfigurationManager: PrivacyConfigurationManaging,
         userContentControllerFuture: some Publisher<some UserContentControllerProtocol, Never>,
         clickToLoadUserScriptPublisher: some Publisher<ClickToLoadUserScript?, Never>) {
        self.privacyConfigurationManager = privacyConfigurationManager

        userContentControllerFuture.sink { [weak self] userContentController in
            self?.userContentController = userContentController
        }.store(in: &cancellables)
        clickToLoadUserScriptPublisher.sink { [weak self] clickToLoadUserScript in
            clickToLoadUserScript?.delegate = self
        }.store(in: &cancellables)
    }

}

extension FBProtectionTabExtension {

    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
        setFBProtection(enabled: featureEnabled)
    }

    @discardableResult
    private func setFBProtection(enabled: Bool) -> Bool {
        guard self.fbBlockingEnabled != enabled else { return false }
        guard let userContentController else {
            assertionFailure("Missing UserContentController")
            return false
        }
        if enabled {
            do {
                try userContentController.enableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("Missing FB List")
                return false
            }
        } else {
            do {
                try userContentController.disableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("FB List was not enabled")
                return false
            }
        }
        self.fbBlockingEnabled = enabled

        return true
    }

}

extension FBProtectionTabExtension: ClickToLoadUserScriptDelegate {

    func clickToLoadUserScriptAllowFB(_ script: UserScript, replyHandler: @escaping (Bool) -> Void) {
        guard self.fbBlockingEnabled else {
            replyHandler(true)
            return
        }

        if setFBProtection(enabled: false) {
            replyHandler(true)
        } else {
            replyHandler(false)
        }
    }
}

extension FBProtectionTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        toggleFBProtection(for: navigationAction.url)
        return .next
    }

}

protocol FbBlockingEnabledProvider {
    var fbBlockingEnabled: Bool { get }
}

protocol FBProtectionExtensionProtocol: AnyObject, FbBlockingEnabledProvider, NavigationResponder {
}

extension FBProtectionTabExtension: TabExtension, FBProtectionExtensionProtocol {
    typealias PublicProtocol = FBProtectionExtensionProtocol

    func getPublicProtocol() -> PublicProtocol { self }

}

extension TabExtensions {
    var fbProtection: FBProtectionExtensionProtocol? {
        resolve(FBProtectionTabExtension.self)
    }
}
