//
//  AdClickAttribution.swift
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

import os.log
import Combine
import Common
import ContentBlocking
import Foundation
import BrowserServicesKit
import PrivacyDashboard
import WebKit

protocol AdClickAttributionDependencies {

    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
    var contentBlockingManager: ContentBlockerRulesManagerProtocol { get }
    var tld: TLD { get }

    var adClickAttribution: AdClickAttributing { get }
    var adClickAttributionRulesProvider: AdClickAttributionRulesProviding { get }

    var attributionEvents: EventMapping<AdClickAttributionEvents> { get }
    var attributionDebugEvents: EventMapping<AdClickAttributionDebugEvents> { get }

}

protocol UserContentControllerProtocol: AnyObject {
    func enableGlobalContentRuleList(withIdentifier identifier: String) throws
    func disableGlobalContentRuleList(withIdentifier identifier: String) throws
    func removeLocalContentRuleList(withIdentifier identifier: String)
    func installLocalContentRuleList(_ ruleList: WKContentRuleList, identifier: String)
}
typealias UserContentControllerProvider = () -> UserContentControllerProtocol?

final class AdClickAttributionTabExtension: TabExtension {

    private static func makeAdClickAttributionDetection(with dependencies: some AdClickAttributionDependencies) -> AdClickAttributionDetection {
        return AdClickAttributionDetection(feature: dependencies.adClickAttribution,
                                           tld: dependencies.tld,
                                           eventReporting: dependencies.attributionEvents,
                                           errorReporting: dependencies.attributionDebugEvents,
                                           log: OSLog.attribution)

    }

    private static func makeAdClickAttributionLogic(with dependencies: some AdClickAttributionDependencies) -> AdClickAttributionLogic {
        return AdClickAttributionLogic(featureConfig: dependencies.adClickAttribution,
                                       rulesProvider: dependencies.adClickAttributionRulesProvider,
                                       tld: dependencies.tld,
                                       eventReporting: dependencies.attributionEvents,
                                       errorReporting: dependencies.attributionDebugEvents,
                                       log: OSLog.attribution)
    }

    private let dependencies: any AdClickAttributionDependencies

    private let userContentControllerProvider: UserContentControllerProvider
    private weak var contentBlockerRulesScript: ContentBlockerRulesUserScript?
    private var cancellables = Set<AnyCancellable>()

    private(set) var detection: AdClickAttributionDetection!
    private(set) var logic: AdClickAttributionLogic!

    public var currentAttributionState: AdClickAttributionLogic.State? {
        logic.state
    }

    init(inheritedAttribution: AdClickAttributionLogic.State?,
         userContentControllerProvider: @escaping UserContentControllerProvider,
         contentBlockerRulesScriptPublisher: some Publisher<ContentBlockerRulesUserScript?, Never>,
         privacyInfoPublisher: some Publisher<PrivacyInfo?, Never>,
         dependencies: some AdClickAttributionDependencies) {

        self.dependencies = dependencies
        self.userContentControllerProvider = userContentControllerProvider

        self.detection = Self.makeAdClickAttributionDetection(with: dependencies)
        self.logic = Self.makeAdClickAttributionLogic(with: dependencies)

        logic.delegate = self
        detection.delegate = logic

        if let state = inheritedAttribution {
            logic.applyInheritedAttribution(state: state)
        }

        contentBlockerRulesScriptPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contentBlockerRulesScript in
                guard let self else { return }
                self.contentBlockerRulesScript = contentBlockerRulesScript
                self.logic.onRulesChanged(latestRules: self.dependencies.contentBlockingManager.currentRules)
            }
            .store(in: &cancellables)

        privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .scan( (old: Set<DetectedRequest>(), new: Set<DetectedRequest>()) ) {
                ($0.new, $1.trackers)
            }
            .sink { [weak self] (old, new) in
                for tracker in new.subtracting(old) {
                    self?.logic.onRequestDetected(request: tracker)
                }
            }
            .store(in: &cancellables)
    }

}

extension AdClickAttributionTabExtension: AdClickAttributionLogicDelegate {

    func attributionLogic(_ logic: AdClickAttributionLogic,
                          didRequestRuleApplication rules: ContentBlockerRulesManager.Rules?,
                          forVendor vendor: String?) {
        guard let userContentController = userContentControllerProvider(),
              let contentBlockerRulesScript
        else {
            assertionFailure("UserScripts not loaded")
            return
        }

        let attributedTempListName = AdClickAttributionRulesProvider.Constants.attributedTempRuleListName

        guard dependencies.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking)
        else {
            userContentController.removeLocalContentRuleList(withIdentifier: attributedTempListName)
            contentBlockerRulesScript.currentAdClickAttributionVendor = nil
            contentBlockerRulesScript.supplementaryTrackerData = []
            return
        }

        contentBlockerRulesScript.currentAdClickAttributionVendor = vendor
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

            contentBlockerRulesScript.supplementaryTrackerData = [rules.trackerData]
        } else {
            contentBlockerRulesScript.supplementaryTrackerData = []
        }
    }

}

extension AppContentBlocking: AdClickAttributionDependencies {}

protocol AdClickAttributionProtocol {
    var detection: AdClickAttributionDetection! { get }
    var logic: AdClickAttributionLogic! { get }
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

