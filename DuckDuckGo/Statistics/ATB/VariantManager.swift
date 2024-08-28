//
//  VariantManager.swift
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import os.log

struct Variant: BrowserServicesKit.Variant {

    struct When {
        static let always = { return true }

        static let inRequiredCountry = { return ["AU", "AT", "DK", "FI", "FR", "DE", "IT", "IE", "NZ", "NO", "ES", "SE", "GB"]
            .contains(where: { Locale.current.regionCode == $0 }) }

        static let inEnglish = { return Locale.current.languageCode == "en" }
    }

    static let doNotAllocate = 0

    // Note: Variants with `doNotAllocate` weight, should always be included so that previous installations are unaffected
    static let defaultVariants: [Variant] = [
    ]

    var name: String
    var weight: Int
    var isIncluded: () -> Bool
    var features: [FeatureName]

}

protocol VariantRNG {

    func nextInt(upperBound: Int) -> Int

}

final class DefaultVariantManager: VariantManager {

    var currentVariant: BrowserServicesKit.Variant? {
        let variantName = ProcessInfo.processInfo.environment["VARIANT", default: storage.variant ?? "" ]
        return variants.first(where: { $0.name == variantName })
    }

    private let variants: [Variant]
    private let storage: StatisticsStore
    private let rng: VariantRNG
    private let campaignVariant: CampaignVariant

    init(variants: [Variant] = Variant.defaultVariants,
         storage: StatisticsStore = LocalStatisticsStore(),
         rng: VariantRNG = Arc4RandomUniformVariantRNG(),
         campaignVariant: CampaignVariant = CampaignVariant()) {
        self.variants = variants
        self.storage = storage
        self.rng = rng
        self.campaignVariant = campaignVariant
    }

    func isSupported(feature: FeatureName) -> Bool {
        return currentVariant?.features.contains(feature) ?? false
    }

    func assignVariantIfNeeded(_ newInstallCompletion: (VariantManager) -> Void) {
        guard !storage.hasInstallStatistics else {
            Logger.atb.debug("ATB: No new variant needed for existing user")
            return
        }

        if let variant = currentVariant {
            Logger.atb.debug("ATB: Already assigned variant: \(String(describing: variant))")
            return
        }

        guard let variant = selectVariant() else {
            Logger.atb.debug("ATB: Failed to assign variant")

            // it's possible this failed because there are none to assign, we should still let new install logic execute
            _ = newInstallCompletion(self)
            return
        }

        storage.variant = variant
        newInstallCompletion(self)
    }

    private func selectVariant() -> String? {
        // Prioritise campaign variants
        if let variant = campaignVariant.getAndEnableVariant() {
            return variant
        }

        let totalWeight = variants.reduce(0, { $0 + $1.weight })
        let randomPercent = rng.nextInt(upperBound: totalWeight)

        var runningTotal = 0
        for variant in variants {
            runningTotal += variant.weight
            if randomPercent < runningTotal {
                return variant.isIncluded() ? variant.name : nil
            }
        }

        return nil
    }

}

final class Arc4RandomUniformVariantRNG: VariantRNG {

    init() { }

    func nextInt(upperBound: Int) -> Int {
        // swiftlint:disable:next legacy_random
        return Int(arc4random_uniform(UInt32(upperBound)))
    }

}

final class CampaignVariant {

    @UserDefaultsWrapper(key: .campaignVariant, defaultValue: false)
    private var isCampaignVariant: Bool

    private let statisticsStore: StatisticsStore
    private let loadFromFile: () -> String?

    init(statisticsStore: StatisticsStore = LocalStatisticsStore(), loadFromFile: @escaping () -> String? = {
        if let url = Bundle.main.url(forResource: "variant", withExtension: "txt") {
            return try? String(contentsOf: url)
        }
        return nil
    }) {
        self.statisticsStore = statisticsStore
        self.loadFromFile = loadFromFile
    }

    // Should only be called during the first installation
    func getAndEnableVariant() -> String? {
        assert(statisticsStore.variant == nil)
        if let string = loadFromFile() {
            isCampaignVariant = true
            return string.trimmingWhitespace()
        }
        return nil
    }

    func daysSinceInstall(_ today: Date = Date()) -> Int {
        guard let installDate = statisticsStore.installDate,
              let days = Calendar.current.numberOfDaysBetween(installDate, and: today) else { return -1 }
        return days
    }

    var isActive: Bool {
        // 93 days is used for our campaign specific retention calculations
        return isCampaignVariant && (0...93).contains(daysSinceInstall())
    }

    func cleanUp() {
        isCampaignVariant = false
    }

}
