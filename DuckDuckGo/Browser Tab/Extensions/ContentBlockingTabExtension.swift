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
import ContentBlocking
import Foundation

protocol FbBlockingEnabledProvider {
    var fbBlockingEnabled: Bool { get }
}

struct DetectedTracker {
    enum TrackerType {
        case blockedTracker
        case trackerWithSurrogate(host: String)
        case thirdPartyRequest
    }
    let request: DetectedRequest
    let type: TrackerType

    var isBlockedTracker: Bool {
        if case .blockedTracker = type { return true }
        return false
    }
}

final class ContentBlockingTabExtension: NSObject {

    private let tabIdentifier: UInt64
    private let fbBlockingEnabledProvider: FbBlockingEnabledProvider
    private let cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
    private let userContentControllerProvider: UserContentControllerProvider
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private var trackersSubject = PassthroughSubject<DetectedTracker, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(tabIdentifier: UInt64,
         fbBlockingEnabledProvider: FbBlockingEnabledProvider,
         contentBlockerRulesUserScriptPublisher: some Publisher<ContentBlockerRulesUserScript?, Never>,
         surrogatesUserScriptPublisher: some Publisher<SurrogatesUserScript?, Never>,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         userContentControllerProvider: @escaping UserContentControllerProvider,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared) {

        self.tabIdentifier = tabIdentifier
        self.cbaTimeReporter = cbaTimeReporter
        self.fbBlockingEnabledProvider = fbBlockingEnabledProvider
        self.privacyConfigurationManager = privacyConfigurationManager
        self.userContentControllerProvider = userContentControllerProvider
        super.init()

        contentBlockerRulesUserScriptPublisher.sink { [weak self] contentBlockerRulesUserScript in
            contentBlockerRulesUserScript?.delegate = self
        }.store(in: &cancellables)
        surrogatesUserScriptPublisher.sink { [weak self] surrogatesUserScript in
            surrogatesUserScript?.delegate = self
        }.store(in: &cancellables)
    }

    deinit {
        cbaTimeReporter?.tabWillClose(tabIdentifier)
    }

}

extension ContentBlockingTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if !navigationAction.url.isDuckDuckGo {
            await prepareForContentBlocking()
        }

        return .next
    }

    @MainActor
    private func prepareForContentBlocking() async {
        guard let userContentController = userContentControllerProvider() else {
            assertionFailure("Could not get userContentController")
            return
        }
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if userContentController.contentBlockingAssetsInstalled == false
            && privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
            cbaTimeReporter?.tabWillWaitForRulesCompilation(tabIdentifier)
            await userContentController.awaitContentBlockingAssetsInstalled()
            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(tabIdentifier)
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
        trackersSubject.send(DetectedTracker(request: tracker, type: .blockedTracker))
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        trackersSubject.send(DetectedTracker(request: request, type: .thirdPartyRequest))
    }

}

extension ContentBlockingTabExtension: SurrogatesUserScriptDelegate {

    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
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

extension FBProtectionTabExtension: FbBlockingEnabledProvider {}
