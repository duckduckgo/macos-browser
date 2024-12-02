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
import PixelKit
import os.log

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
        let domainEvent: GeneralPixel
        let dailyAndCount: Bool

        var parameters = parameters ?? [:]

        if let error = error as? NSError {
            let processedErrors = CoreDataErrorsParser.parse(error: error)
            let additionalCoreDataParameters = processedErrors.errorPixelParameters
            parameters.merge(additionalCoreDataParameters) { (current, _) in current }
        }

        switch event {
        case .dbSaveBloomFilterError:
            domainEvent = GeneralPixel.dbSaveBloomFilterError(error: error)
            dailyAndCount = true
        case .dbSaveExcludedHTTPSDomainsError:
            domainEvent = GeneralPixel.dbSaveExcludedHTTPSDomainsError(error: error)
            dailyAndCount = false
        }

        if dailyAndCount {
            PixelKit.fire(DebugEvent(domainEvent, error: error),
                          frequency: .legacyDailyAndCount,
                          withAdditionalParameters: parameters,
                          includeAppVersionParameter: true) { _, error in
                onComplete(error)
            }
        } else {
            PixelKit.fire(DebugEvent(domainEvent, error: error),
                          frequency: .legacyDailyAndCount,
                          withAdditionalParameters: parameters) { _, error in
                onComplete(error)
            }
        }
    }
    private static var embeddedBloomFilterResources: EmbeddedBloomFilterResources {
        EmbeddedBloomFilterResources(bloomSpecification: Bundle.main.url(forResource: "httpsMobileV2BloomSpec", withExtension: "json")!,
                                     bloomFilter: Bundle.main.url(forResource: "httpsMobileV2Bloom", withExtension: "bin")!,
                                     excludedDomains: Bundle.main.url(forResource: "httpsMobileV2FalsePositives", withExtension: "json")!)
    }

    convenience init(contentBlocking: AnyContentBlocking, database: CoreDataDatabase) {
        let bloomFilterDataURL = URL.sandboxApplicationSupportURL.appendingPathComponent("HttpsBloomFilter.bin")
        let httpsUpgradeStore = AppHTTPSUpgradeStore(database: database, bloomFilterDataURL: bloomFilterDataURL, embeddedResources: Self.embeddedBloomFilterResources, errorEvents: Self.httpsUpgradeDebugEvents, logger: Logger.httpsUpgrade)
        self.init(contentBlocking: contentBlocking, httpsUpgradeStore: httpsUpgradeStore)
    }

    init(contentBlocking: AnyContentBlocking, httpsUpgradeStore: HTTPSUpgradeStore) {
        self.contentBlocking = contentBlocking
        self.httpsUpgrade = HTTPSUpgrade(store: httpsUpgradeStore, privacyManager: contentBlocking.privacyConfigurationManager, logger: Logger.httpsUpgrade)
    }

}
