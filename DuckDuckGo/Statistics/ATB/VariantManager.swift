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

import Common
import Foundation

enum FeatureName: String {

    // Used for unit tests
    case dummy

}

struct Variant {

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

    let name: String
    let weight: Int
    let isIncluded: () -> Bool
    let features: [FeatureName]

}

protocol VariantRNG {

    func nextInt(upperBound: Int) -> Int

}

protocol VariantManager {

    var currentVariant: Variant? { get }
    func assignVariantIfNeeded(_ newInstallCompletion: (VariantManager) -> Void)
    func isSupported(feature: FeatureName) -> Bool

}

final class DefaultVariantManager: VariantManager {

    var currentVariant: Variant? {
        let variantName = ProcessInfo.processInfo.environment["VARIANT", default: storage.variant ?? "" ]
        return variants.first(where: { $0.name == variantName })
    }

    private let variants: [Variant]
    private let storage: StatisticsStore
    private let rng: VariantRNG

    init(variants: [Variant] = Variant.defaultVariants,
         storage: StatisticsStore = LocalStatisticsStore(),
         rng: VariantRNG = Arc4RandomUniformVariantRNG()) {
        self.variants = variants
        self.storage = storage
        self.rng = rng
    }

    func isSupported(feature: FeatureName) -> Bool {
        return currentVariant?.features.contains(feature) ?? false
    }

    func assignVariantIfNeeded(_ newInstallCompletion: (VariantManager) -> Void) {
        guard !storage.hasInstallStatistics else {
            os_log("ATB: No new variant needed for existing user", type: .debug)
            return
        }

        if let variant = currentVariant {
            os_log("ATB: Already assigned variant: %s", type: .debug, String(describing: variant))
            return
        }

        guard let variant = selectVariant() else {
            os_log("ATB: Failed to assign variant", type: .debug)

            // it's possible this failed because there are none to assign, we should still let new install logic execute
            _ = newInstallCompletion(self)
            return
        }

        storage.variant = variant.name
        newInstallCompletion(self)
    }

    private func selectVariant() -> Variant? {
        let totalWeight = variants.reduce(0, { $0 + $1.weight })
        let randomPercent = rng.nextInt(upperBound: totalWeight)

        var runningTotal = 0
        for variant in variants {
            runningTotal += variant.weight
            if randomPercent < runningTotal {
                return variant.isIncluded() ? variant : nil
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
