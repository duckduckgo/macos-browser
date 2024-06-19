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
    private weak var clickToLoadUserScript: ClickToLoadUserScript?

    private var cancellables = Set<AnyCancellable>()

    let fbEntity = "Facebook, Inc."

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
            self?.clickToLoadUserScript = clickToLoadUserScript
        }.store(in: &cancellables)
    }

    @MainActor
    public func trackerDetected() {
        clickToLoadUserScript?.displayClickToLoadPlaceholders()
    }
}

extension FBProtectionTabExtension {

    private func setFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToLoad, enabledForDomain: url.host)
        setFBProtection(enable: featureEnabled)
    }

    @discardableResult
    private func setFBProtection(enable: Bool) -> Bool {
        if #unavailable(OSX 11) {  // disable CTL for Catalina and earlier
            return false
        }
        guard self.fbBlockingEnabled != enable else { return false }
        guard let userContentController else {
            assertionFailure("Missing UserContentController")
            return false
        }
        if enable {
            do {
                try userContentController.enableGlobalContentRuleList(withIdentifier: DefaultContentBlockerRulesListsSource.Constants.clickToLoadRulesListName)
            } catch {
                return false
            }
        } else {
            do {
                try userContentController.disableGlobalContentRuleList(withIdentifier: DefaultContentBlockerRulesListsSource.Constants.clickToLoadRulesListName)
            } catch {
                return false
            }
        }
        self.fbBlockingEnabled = enable

        return true
    }

}

extension FBProtectionTabExtension: ClickToLoadUserScriptDelegate {

    func clickToLoadUserScriptAllowFB() -> Bool {
        guard self.fbBlockingEnabled else {
            return true
        }

        if setFBProtection(enable: false) {
            return true
        } else {
            return false
        }
    }

}

extension FBProtectionTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if navigationAction.navigationType == NavigationType.other && navigationAction.isUserInitiated == false {
            return .next
        }
        setFBProtection(for: navigationAction.url)
        return .next
    }

}

protocol FbBlockingEnabledProvider {
    var fbBlockingEnabled: Bool { get }
    var fbEntity: String { get }
    func trackerDetected()
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
