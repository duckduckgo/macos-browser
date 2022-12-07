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

protocol ContentBlockingAssetsPublisherProvider {
    var contentBlockingAssetsPublisher: AnyPublisher<UserContentController.ContentBlockingAssets?, Never> { get }
}
protocol PrivacyConfigurationManagerProvider {
    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
}
protocol AdClickAttributionStateProvider {
    var inheritedAttribution: AdClickAttributionLogic.State? { get }
}
protocol PrivacyInfoPublisherProvider {
    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> { get }
}
protocol UserContentControllerProtocol {
    func enableGlobalContentRuleList(withIdentifier identifier: String) throws
    func disableGlobalContentRuleList(withIdentifier identifier: String) throws
    func removeLocalContentRuleList(withIdentifier identifier: String)
    func installLocalContentRuleList(_ ruleList: WKContentRuleList, identifier: String)
}
protocol UserContentControllerProvider {
    var anyUserContentController: UserContentControllerProtocol? { get }
}
protocol ContentBlockerRulesPublisherProvider {
    var contentBlockerRulesScriptPublisher: AnyPublisher<ContentBlockerRulesUserScript?, Never> { get }
}

final class AdClickAttributionTabExtension {

    private static func makeAdClickAttributionFeature(with privacyConfigurationManager: PrivacyConfigurationManaging) -> AdClickAttributionFeature {
        AdClickAttributionFeature(with: privacyConfigurationManager)
    }
    private static func makeAdClickAttributionDetection(featureConfig: AdClickAttributing) -> AdClickAttributionDetection {
#if DEBUG
        if AppDelegate.isRunningTests {
            return AdClickAttributionDetection(feature: featureConfig,
                                               tld: TLD(),
                                               eventReporting: nil,
                                               errorReporting: nil,
                                               log: .disabled)
        }
#endif
        return AdClickAttributionDetection(feature: featureConfig,
                                           tld: ContentBlocking.shared.tld,
                                           eventReporting: ContentBlocking.shared.attributionEvents,
                                           errorReporting: ContentBlocking.shared.attributionDebugEvents,
                                           log: OSLog.attribution)

    }

    private static func makeAdClickAttributionLogic(featureConfig: AdClickAttributing) -> AdClickAttributionLogic {
#if DEBUG
        if AppDelegate.isRunningTests {
            let rulesProvider: AdClickAttributionRulesProviding =
                ((NSClassFromString("EmptyAttributionRulesProver") as? (NSObject).Type)!.init() as? AdClickAttributionRulesProviding)!

            return AdClickAttributionLogic(featureConfig: featureConfig,
                                           rulesProvider: rulesProvider,
                                           tld: TLD(),
                                           eventReporting: nil,
                                           errorReporting: nil,
                                           log: .disabled)
        }
#endif
        return AdClickAttributionLogic(featureConfig: ContentBlocking.shared.adClickAttribution,
                                       rulesProvider: ContentBlocking.shared.adClickAttributionRulesProvider,
                                       tld: ContentBlocking.shared.tld,
                                       eventReporting: ContentBlocking.shared.attributionEvents,
                                       errorReporting: ContentBlocking.shared.attributionDebugEvents,
                                       log: OSLog.attribution)
    }

    private(set) var detection: AdClickAttributionDetection!
    private(set) var logic: AdClickAttributionLogic!

    typealias Dependencies = ContentBlockingAssetsPublisherProvider
        & PrivacyConfigurationManagerProvider
        & AdClickAttributionStateProvider
        & PrivacyInfoPublisherProvider
        & ContentBlockerRulesPublisherProvider
        & UserContentControllerProvider
    private var dependencies: Dependencies!
    private weak var contentBlockerRulesScript: ContentBlockerRulesUserScript?

    private var cancellables = Set<AnyCancellable>()

    static var currentRules: () -> [ContentBlockerRulesManager.Rules] = { ContentBlocking.shared.contentBlockingManager.currentRules }

    private var state: AdClickAttributionLogic.State? {
        logic.state
    }

    public var currentAttributionState: AdClickAttributionLogic.State? {
        logic.state
    }

    init(provider: some Dependencies) {
        self.dependencies = provider

        let adClickAttributionFeature = Self.makeAdClickAttributionFeature(with: dependencies.privacyConfigurationManager)
        self.detection = Self.makeAdClickAttributionDetection(featureConfig: adClickAttributionFeature)
        self.logic = Self.makeAdClickAttributionLogic(featureConfig: adClickAttributionFeature)

        logic.delegate = self
        detection.delegate = logic

        if let state = dependencies.inheritedAttribution {
            logic.applyInheritedAttribution(state: state)
        }

        dependencies.contentBlockerRulesScriptPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contentBlockerRulesScript in
                self?.contentBlockerRulesScript = contentBlockerRulesScript
                self?.logic.onRulesChanged(latestRules: Self.currentRules())
            }
            .store(in: &cancellables)

        dependencies.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
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
        guard let userContentController = dependencies?.anyUserContentController, let contentBlockerRulesScript else {
            assertionFailure("UserScripts not loaded")
            return
        }

        let attributedTempListName = AdClickAttributionRulesProvider.Constants.attributedTempRuleListName

        guard ContentBlocking.shared.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking)
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

extension AdClickAttributionTabExtension: TabExtension {
    final class ResolvingHelper: TabExtensionResolvingHelper {
        static func make(owner: Tab) -> AdClickAttributionTabExtension {
            // TODO: make it WEAK
            AdClickAttributionTabExtension(provider: owner)
        }
    }
}

extension TabExtensions {
    var adClickAttribution: AdClickAttributionTabExtension? {
        resolve()
    }
}

extension Tab: ContentBlockingAssetsPublisherProvider {
    var contentBlockingAssetsPublisher: AnyPublisher<BrowserServicesKit.UserContentController.ContentBlockingAssets?, Never> {
        $userContentController.compactMap { $0?.$contentBlockingAssets }.switchToLatest().eraseToAnyPublisher()
    }
}
extension Tab: AdClickAttributionStateProvider {
    var inheritedAttribution: AdClickAttributionLogic.State? {
        self.parentTab?.extensions.adClickAttribution?.currentAttributionState
    }
}
extension Tab: PrivacyConfigurationManagerProvider {}
extension Tab: PrivacyInfoPublisherProvider {
    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> {
        $privacyInfo.eraseToAnyPublisher()
    }
}
extension Tab: UserContentControllerProvider {
    var anyUserContentController: UserContentControllerProtocol? { userContentController }
}
extension UserContentController: UserContentControllerProtocol {}
extension Tab: ContentBlockerRulesPublisherProvider {
    var contentBlockerRulesScriptPublisher: AnyPublisher<BrowserServicesKit.ContentBlockerRulesUserScript?, Never> {
        userScriptsPublisher.compactMap { $0?.contentBlockerRulesScript }.eraseToAnyPublisher()
    }
}
