//
//  ContentBlockingTabExtension.swift
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
import Common
import ContentBlocking
import Foundation
import Navigation
import Subscription
import os.log

struct DetectedTracker {
    enum TrackerType {
        case tracker
        case trackerWithSurrogate(host: String)
        case thirdPartyRequest
    }
    let request: DetectedRequest
    let type: TrackerType
}

protocol ContentBlockingAssetsInstalling: AnyObject {
    var contentBlockingAssetsInstalled: Bool { get }
    var awaitContentBlockingAssetsInstalled: () async -> Void { get }
}
extension UserContentController: ContentBlockingAssetsInstalling {}

final class ContentBlockingTabExtension: NSObject {
    private static var idCounter: UInt64 = 0
    private let identifier: UInt64 = {
        defer { idCounter += 1 }
        return ContentBlockingTabExtension.idCounter
    }()

    private weak var userContentController: ContentBlockingAssetsInstalling?
    private let cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let fbBlockingEnabledProvider: FbBlockingEnabledProvider
    private var trackersSubject = PassthroughSubject<DetectedTracker, Never>()

    private var cancellables = Set<AnyCancellable>()

#if DEBUG
    /// set this to true when Navigation-related decision making is expected to take significant time to avoid assertions
    /// used by BSK: Navigation.DistributedNavigationDelegate
    var shouldDisableLongDecisionMakingChecks: Bool = false
    func disableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = true }
    func enableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = false }
#else
    func disableLongDecisionMakingChecks() {}
    func enableLongDecisionMakingChecks() {}
#endif

    init(fbBlockingEnabledProvider: FbBlockingEnabledProvider,
         userContentControllerFuture: some Publisher<some ContentBlockingAssetsInstalling, Never>,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         contentBlockerRulesUserScriptPublisher: some Publisher<ContentBlockerRulesUserScript?, Never>,
         surrogatesUserScriptPublisher: some Publisher<SurrogatesUserScript?, Never>) {

        self.cbaTimeReporter = cbaTimeReporter
        self.fbBlockingEnabledProvider = fbBlockingEnabledProvider
        self.privacyConfigurationManager = privacyConfigurationManager
        super.init()

        userContentControllerFuture.sink { [weak self] userContentController in
            self?.userContentController = userContentController
        }.store(in: &cancellables)
        contentBlockerRulesUserScriptPublisher.sink { [weak self] contentBlockerRulesUserScript in
            contentBlockerRulesUserScript?.delegate = self
        }.store(in: &cancellables)
        surrogatesUserScriptPublisher.sink { [weak self] surrogatesUserScript in
            surrogatesUserScript?.delegate = self
        }.store(in: &cancellables)
    }

    deinit {
        cbaTimeReporter?.tabWillClose(identifier)
    }

}

extension ContentBlockingTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if !navigationAction.url.isDuckDuckGo
            // ContentScopeUserScript needs to be loaded for https://duckduckgo.com/email/
            || navigationAction.url.absoluteString.hasPrefix(URL.duckDuckGoEmailLogin.absoluteString)
            // ContentScopeUserScript needs to be loaded for https://duckduckgo.com/subscriptions
            || navigationAction.url.absoluteString.hasPrefix(SubscriptionURL.baseURL.subscriptionURL(environment: .production).absoluteString)
            // ContentScopeUserScript needs to be loaded for https://duckduckgo.com/identity-theft-restoration
            || navigationAction.url.absoluteString.hasPrefix(SubscriptionURL.identityTheftRestoration.subscriptionURL(environment: .production).absoluteString) {
            await prepareForContentBlocking()
        }

        return .next
    }

    @MainActor
    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if userContentController?.contentBlockingAssetsInstalled == false
            && privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
            Logger.contentBlocking.log("\(self.identifier) tabWillWaitForRulesCompilation")
            cbaTimeReporter?.tabWillWaitForRulesCompilation(identifier)

            disableLongDecisionMakingChecks()
            defer {
                enableLongDecisionMakingChecks()
            }

            await userContentController?.awaitContentBlockingAssetsInstalled()
            Logger.contentBlocking.log("\(self.identifier) Rules Compilation done")
            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(identifier)
        } else {
            cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        }
    }

}

extension ContentBlockingTabExtension: ContentBlockerRulesUserScriptDelegate {

    func contentBlockerRulesUserScriptShouldProcessTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return true
    }

    func contentBlockerRulesUserScriptShouldProcessCTLTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return fbBlockingEnabledProvider.fbBlockingEnabled
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedTracker tracker: DetectedRequest) {
        trackersSubject.send(DetectedTracker(request: tracker, type: .tracker))
        if tracker.state == BlockingState.blocked && tracker.ownerName == fbBlockingEnabledProvider.fbEntity {
            fbBlockingEnabledProvider.trackerDetected()
        }
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        trackersSubject.send(DetectedTracker(request: request, type: .thirdPartyRequest))
    }

}

extension ContentBlockingTabExtension: SurrogatesUserScriptDelegate {

    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
    }

    func surrogatesUserScriptShouldProcessCTLTrackers(_ script: SurrogatesUserScript) -> Bool {
        fbBlockingEnabledProvider.fbBlockingEnabled
    }

    func surrogatesUserScript(_ script: SurrogatesUserScript, detectedTracker tracker: DetectedRequest, withSurrogate host: String) {
        trackersSubject.send(DetectedTracker(request: tracker, type: .trackerWithSurrogate(host: host)))
    }
}

protocol ContentBlockingExtensionProtocol: AnyObject, NavigationResponder {
    var trackersPublisher: AnyPublisher<DetectedTracker, Never> { get }
}

extension ContentBlockingTabExtension: TabExtension, ContentBlockingExtensionProtocol {
    typealias PublicProtocol = ContentBlockingExtensionProtocol

    func getPublicProtocol() -> PublicProtocol { self }

    var trackersPublisher: AnyPublisher<DetectedTracker, Never> {
        trackersSubject.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var contentBlockingAndSurrogates: ContentBlockingExtensionProtocol? {
        resolve(ContentBlockingTabExtension.self)
    }
}

extension Tab {
    var trackersPublisher: AnyPublisher<DetectedTracker, Never> {
        self.contentBlockingAndSurrogates?.trackersPublisher ?? PassthroughSubject().eraseToAnyPublisher()
    }
}
