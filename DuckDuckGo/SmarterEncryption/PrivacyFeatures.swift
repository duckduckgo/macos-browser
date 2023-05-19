//
//  PrivacyFeatures.swift
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
import Common
import Foundation
import Persistence

protocol PrivacyFeaturesProtocol {
    var contentBlocking: AnyContentBlocking { get }

    var httpsUpgrade: HTTPSUpgrade { get }
}
typealias AnyPrivacyFeatures = any PrivacyFeaturesProtocol

// refactor: var PrivacyFeatures to be removed, PrivacyFeaturesProtocol to be renamed to PrivacyFeatures
// PrivacyFeatures to be passed to init methods as `some PrivacyFeatures`
// swiftlint:disable:next identifier_name
var PrivacyFeatures: AnyPrivacyFeatures {
    AppPrivacyFeatures.shared
}

final class AppPrivacyFeatures: PrivacyFeaturesProtocol {
    static var shared: AnyPrivacyFeatures!

    let contentBlocking: AnyContentBlocking
    let httpsUpgrade: HTTPSUpgrade

    private static let httpsUpgradeDebugEvents = EventMapping<AppHTTPSUpgradeStore.ErrorEvents> { event, error, parameters, onComplete in
        let domainEvent: Pixel.Event.Debug
        switch event {
        case .dbSaveBloomFilterError:
            domainEvent = .dbSaveBloomFilterError
        case .dbSaveExcludedHTTPSDomainsError:
            domainEvent = .dbSaveExcludedHTTPSDomainsError
        }

        Pixel.fire(.debug(event: domainEvent, error: error), withAdditionalParameters: parameters, onComplete: onComplete)
    }
    private static var embeddedBloomFilterResources: EmbeddedBloomFilterResources {
        EmbeddedBloomFilterResources(bloomSpecification: Bundle.main.url(forResource: "httpsMobileV2BloomSpec", withExtension: "json")!,
                                     bloomFilter: Bundle.main.url(forResource: "httpsMobileV2Bloom", withExtension: "bin")!,
                                     excludedDomains: Bundle.main.url(forResource: "httpsMobileV2FalsePositives", withExtension: "json")!)
    }

    convenience init(contentBlocking: AnyContentBlocking, database: CoreDataDatabase) {
        let bloomFilterDataURL = URL.sandboxApplicationSupportURL.appendingPathComponent("HttpsBloomFilter.bin")
        let httpsUpgradeStore = AppHTTPSUpgradeStore(database: database, bloomFilterDataURL: bloomFilterDataURL, embeddedResources: Self.embeddedBloomFilterResources, errorEvents: Self.httpsUpgradeDebugEvents, log: .httpsUpgrade)
        self.init(contentBlocking: contentBlocking, httpsUpgradeStore: httpsUpgradeStore)
    }

    init(contentBlocking: AnyContentBlocking, httpsUpgradeStore: HTTPSUpgradeStore) {
        self.contentBlocking = contentBlocking
        self.httpsUpgrade = HTTPSUpgrade(store: httpsUpgradeStore, privacyManager: contentBlocking.privacyConfigurationManager, log: .httpsUpgrade)
    }

}
