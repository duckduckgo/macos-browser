//
//  AdClickAttributionTabExtension.swift
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
import PrivacyDashboard
import TrackerRadarKit
import WebKit
import os.log

protocol AdClickAttributionDependencies {

    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
    var contentBlockingManager: ContentBlockerRulesManagerProtocol { get }
    var tld: TLD { get }

    var adClickAttribution: AdClickAttributing { get }
    var adClickAttributionRulesProvider: AdClickAttributionRulesProviding { get }

    var attributionEvents: EventMapping<AdClickAttributionEvents>? { get }
    var attributionDebugEvents: EventMapping<AdClickAttributionDebugEvents>? { get }

}

protocol UserContentControllerProtocol: AnyObject {
    var contentBlockingAssetsInstalled: Bool { get }

    func enableGlobalContentRuleList(withIdentifier identifier: String) throws
    func disableGlobalContentRuleList(withIdentifier identifier: String) throws
    func removeLocalContentRuleList(withIdentifier identifier: String)
    func installLocalContentRuleList(_ ruleList: WKContentRuleList, identifier: String)
}

protocol AdClickAttributionDetecting {
    func onStartNavigation(url: URL?)
    func on2XXResponse(url: URL?)
    func onDidFinishNavigation(url: URL?)
    func onDidFailNavigation()
}
extension AdClickAttributionDetection: AdClickAttributionDetecting {}

protocol AdClickLogicProtocol: AnyObject {
    var state: AdClickAttributionLogic.State { get }
    var delegate: AdClickAttributionLogicDelegate? { get set }

    var debugID: String { get }

    func applyInheritedAttribution(state: AdClickAttributionLogic.State?)
    func onRulesChanged(latestRules: [ContentBlockerRulesManager.Rules])
    func onRequestDetected(request: DetectedRequest)

    func onBackForwardNavigation(mainFrameURL: URL?)
    func onProvisionalNavigation() async
    func onDidFinishNavigation(host: String?, currentTime: Date)
}
extension AdClickAttributionLogic: AdClickLogicProtocol {}

protocol ContentBlockerScriptProtocol: AnyObject {
    var currentAdClickAttributionVendor: String? { get set }
    var supplementaryTrackerData: [TrackerData] { get set }
}
extension ContentBlockerRulesUserScript: ContentBlockerScriptProtocol {}

final class AdClickAttributionTabExtension: TabExtension {

    private static func makeAdClickAttributionDetection(with dependencies: any AdClickAttributionDependencies, delegate: AdClickAttributionLogic) -> AdClickAttributionDetection {
        let detection = AdClickAttributionDetection(feature: dependencies.adClickAttribution,
                                                    tld: dependencies.tld,
                                                    eventReporting: dependencies.attributionEvents,
                                                    errorReporting: dependencies.attributionDebugEvents)
        detection.delegate = delegate
        return detection

    }

    private static func makeAdClickAttributionLogic(with dependencies: any AdClickAttributionDependencies) -> AdClickAttributionLogic {
        return AdClickAttributionLogic(featureConfig: dependencies.adClickAttribution,
                                       rulesProvider: dependencies.adClickAttributionRulesProvider,
                                       tld: dependencies.tld,
                                       eventReporting: dependencies.attributionEvents,
                                       errorReporting: dependencies.attributionDebugEvents)
    }

    private static func makeAdClickAttribution(with dependencies: any AdClickAttributionDependencies) -> (AdClickLogicProtocol, AdClickAttributionDetecting) {
        let logic = makeAdClickAttributionLogic(with: dependencies)
        let detection = makeAdClickAttributionDetection(with: dependencies, delegate: logic)
        return (logic, detection)
    }

    private let dependencies: any AdClickAttributionDependencies

    private weak var userContentController: UserContentControllerProtocol?
    private weak var contentBlockerRulesScript: ContentBlockerScriptProtocol?
    private let dateTimeProvider: () -> Date

    private let detection: AdClickAttributionDetecting
    private let logic: AdClickLogicProtocol

    private var didReceiveRedirectCancellation = false

    public var currentAttributionState: AdClickAttributionLogic.State {
        logic.state
    }

    private var cancellables = Set<AnyCancellable>()

    init(inheritedAttribution: AdClickAttributionLogic.State?,
         userContentControllerFuture: some Publisher<some UserContentControllerProtocol, Never>,
         contentBlockerRulesScriptPublisher: some Publisher<(any ContentBlockerScriptProtocol)?, Never>,
         trackerInfoPublisher: some Publisher<DetectedRequest, Never>,
         dependencies: some AdClickAttributionDependencies,
         dateTimeProvider: @escaping () -> Date = Date.init,
         logicsProvider: (AdClickAttributionDependencies) -> (AdClickLogicProtocol, AdClickAttributionDetecting) = AdClickAttributionTabExtension.makeAdClickAttribution) {

        self.dependencies = dependencies
        self.dateTimeProvider = dateTimeProvider
        (self.logic, self.detection) = logicsProvider(dependencies)

        Logger.contentBlocking.debug("<\(self.logic.debugID)> AttributionLogic created in Tab Extension")
        self.logic.delegate = self

        // delay firing up until UserContentController is published
        userContentControllerFuture.sink { [weak self] userContentController in
            self?.delayedInitialization(with: userContentController,
                                        inheritedAttribution: inheritedAttribution,
                                        contentBlockerRulesScriptPublisher: contentBlockerRulesScriptPublisher,
                                        trackerInfoPublisher: trackerInfoPublisher)
        }.store(in: &cancellables)
    }

    private func delayedInitialization(with userContentController: UserContentControllerProtocol, inheritedAttribution: AdClickAttributionLogic.State?, contentBlockerRulesScriptPublisher: some Publisher<(any ContentBlockerScriptProtocol)?, Never>, trackerInfoPublisher: some Publisher<DetectedRequest, Never>) {

        Logger.contentBlocking.debug("<\(self.logic.debugID)> Performing delayed initialization")

        cancellables.removeAll()
        self.userContentController = userContentController

        if let inheritedAttribution {
            logic.applyInheritedAttribution(state: inheritedAttribution)
        }

        contentBlockerRulesScriptPublisher
            .compactMap { $0 }
            .sink { [weak self] contentBlockerRulesScript in
                guard let self else { return }

                self.contentBlockerRulesScript = contentBlockerRulesScript
                self.logic.onRulesChanged(latestRules: self.dependencies.contentBlockingManager.currentRules)
            }
            .store(in: &cancellables)

        trackerInfoPublisher
            .sink { [weak self] tracker in
                self?.logic.onRequestDetected(request: tracker)
            }
            .store(in: &cancellables)
    }

}

extension AdClickAttributionTabExtension: AdClickAttributionLogicDelegate {

    func attributionLogic(_ logic: AdClickAttributionLogic,
                          didRequestRuleApplication rules: ContentBlockerRulesManager.Rules?,
                          forVendor vendor: String?) {
        guard let userContentController else {
            assertionFailure("UserContentController not set")
            return
        }

        Logger.contentBlocking.debug("<\(self.logic.debugID)> Attribution requesting Rule application for \(vendor ?? "<none>")")

        let attributedTempListName = AdClickAttributionRulesProvider.Constants.attributedTempRuleListName

        guard dependencies.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) else {
            userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
            contentBlockerRulesScript?.currentAdClickAttributionVendor = nil
            contentBlockerRulesScript?.supplementaryTrackerData = []
            return
        }

        contentBlockerRulesScript?.currentAdClickAttributionVendor = vendor
        if let rules = rules {

            let globalListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            let globalAttributionListName = AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: globalListName)

            if vendor != nil {
                userContentController.installLocalContentRuleList(rules.rulesList, identifier: attributedTempListName)
                try? userContentController.disableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            } else {
                userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
                try? userContentController.enableGlobalContentRuleList(withIdentifier: globalAttributionListName)
            }

            contentBlockerRulesScript?.supplementaryTrackerData = [rules.trackerData]
        } else {
            contentBlockerRulesScript?.supplementaryTrackerData = []
        }
    }

}

extension AdClickAttributionTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if navigationAction.isForMainFrame, navigationAction.navigationType.isBackForward {

            logic.onBackForwardNavigation(mainFrameURL: navigationAction.url)
        }
        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        didReceiveRedirectCancellation = false
        detection.onStartNavigation(url: navigation.url)
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        if navigationResponse.isForMainFrame,
           let currentNavigation = navigationResponse.mainFrameNavigation,
           navigationResponse.isSuccessful == true {
            detection.on2XXResponse(url: currentNavigation.url)
        }

        await logic.onProvisionalNavigation()

        return .next
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        guard navigation.isCurrent else { return }

        didReceiveRedirectCancellation = false
        detection.onDidFinishNavigation(url: navigation.url)
        logic.onDidFinishNavigation(host: navigation.url.host, currentTime: dateTimeProvider())
    }

    @MainActor
    func didCancelNavigationAction(_ navigationAction: NavigationAction, withRedirectNavigations expectedNavigations: [ExpectedNavigation]?) {
        if let expectedNavigations, !expectedNavigations.isEmpty {
            didReceiveRedirectCancellation = true
        }
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        guard !didReceiveRedirectCancellation else {
            didReceiveRedirectCancellation = false
            return
        }
        detection.onDidFailNavigation()
    }

}

extension AppContentBlocking: AdClickAttributionDependencies {}

protocol AdClickAttributionProtocol: AnyObject, NavigationResponder {
    var currentAttributionState: AdClickAttributionLogic.State { get }
}

extension AdClickAttributionTabExtension: AdClickAttributionProtocol {
    func getPublicProtocol() -> AdClickAttributionProtocol { self }
}

extension TabExtensions {
    var adClickAttribution: AdClickAttributionProtocol? {
        resolve(AdClickAttributionTabExtension.self)
    }
}

extension UserContentController: UserContentControllerProtocol {}
