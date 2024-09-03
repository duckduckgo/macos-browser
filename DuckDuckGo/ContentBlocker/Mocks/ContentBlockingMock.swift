//
//  ContentBlockingMock.swift
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

import BloomFilterWrapper
import BrowserServicesKit
import Combine
import Common
import Foundation

#if DEBUG

final class ContentBlockingMock: NSObject, ContentBlockingProtocol, AdClickAttributionDependencies {

    struct EDP: EmbeddedDataProvider {
        var embeddedDataEtag: String = ""
        var embeddedData: Data = .init()
    }
    var trackerDataManager = TrackerDataManager(etag: ConfigurationStore().loadEtag(for: .trackerDataSet),
                                                data: ConfigurationStore().loadData(for: .trackerDataSet),
                                                embeddedDataProvider: AppTrackerDataSetProvider(),
                                                errorReporting: nil)

    var tld: Common.TLD = .init()

    typealias ConfigurationManager = MockPrivacyConfigurationManager
    typealias ContentBlockingAssets = UserContentUpdating.NewContent

    typealias ContentBlockingManager = ContentBlockerRulesManagerMock

    let contentBlockingManager: ContentBlockerRulesManagerProtocol = ContentBlockerRulesManagerMock()
    let contentBlockingAssetsSubject = PassthroughSubject<UserContentUpdating.NewContent, Never>()
    var contentBlockingAssetsPublisher: AnyPublisher<UserContentUpdating.NewContent, Never> {  contentBlockingAssetsSubject.eraseToAnyPublisher() }
    let contentBlockerRulesManager = ContentBlockerRulesManagerMock()
    let privacyConfigurationManager: PrivacyConfigurationManaging = MockPrivacyConfigurationManager()

    var adClickAttribution: AdClickAttributing
    var adClickAttributionRulesProvider: AdClickAttributionRulesProviding = MockAttributionRulesProvider()

    var attributionEvents: EventMapping<AdClickAttributionEvents>?
    var attributionDebugEvents: EventMapping<BrowserServicesKit.AdClickAttributionDebugEvents>?

    init(adClickAttributionEnabled: Bool) {
        self.adClickAttribution = MockAttributing(isEnabled: adClickAttributionEnabled)
    }
    override convenience init() {
        self.init(adClickAttributionEnabled: false)
    }
}

final class HTTPSUpgradeStoreMock: NSObject, HTTPSUpgradeStore {

    var bloomFilter: BloomFilterWrapper?
    var bloomFilterSpecification: HTTPSBloomFilterSpecification?

    func loadBloomFilter() -> BrowserServicesKit.BloomFilter? {
        guard let bloomFilter, let bloomFilterSpecification else { return nil }
        return .init(wrapper: bloomFilter, specification: bloomFilterSpecification)
    }

    var excludedDomains: [String] = []
    func hasExcludedDomain(_ domain: String) -> Bool {
        excludedDomains.contains(domain)
    }

    func persistBloomFilter(specification: BrowserServicesKit.HTTPSBloomFilterSpecification, data: Data) throws {
        fatalError()
    }

    func persistExcludedDomains(_ domains: [String]) throws {
        fatalError()
    }

}

final class MockAttributing: AdClickAttributing {

    init(isEnabled: Bool = true,
         onFormatMatching: @escaping (URL) -> Bool = { _ in return true },
         onParameterNameQuery: @escaping (URL) -> String? = { _ in return nil }) {
        self.isEnabled = isEnabled
        self.onFormatMatching = onFormatMatching
        self.onParameterNameQuery = onParameterNameQuery
    }

    var isEnabled: Bool

    var allowlist = [AdClickAttributionFeature.AllowlistEntry]()

    var navigationExpiration: Double = 30
    var totalExpiration: Double = 7 * 24 * 60

    var onFormatMatching: (URL) -> Bool
    var onParameterNameQuery: (URL) -> String?

    func isMatchingAttributionFormat(_ url: URL) -> Bool {
        return onFormatMatching(url)
    }

    func attributionDomainParameterName(for url: URL) -> String? {
        return onParameterNameQuery(url)
    }

    var isHeuristicDetectionEnabled: Bool = true
    var isDomainDetectionEnabled: Bool = true

}

final class MockAttributionRulesProvider: AdClickAttributionRulesProviding {

    enum Constants {
        static let globalAttributionRulesListName = "global"
    }

    init() {
    }

    var globalAttributionRules: ContentBlockerRulesManager.Rules?

    var onRequestingAttribution: (String, @escaping (ContentBlockerRulesManager.Rules?) -> Void) -> Void = { _, _  in }
    func requestAttribution(forVendor vendor: String,
                            completion: @escaping (ContentBlockerRulesManager.Rules?) -> Void) {
        onRequestingAttribution(vendor, completion)
    }

}

#endif
