//
//  FeatureFlagOverrides.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation
import Persistence

public protocol FeatureFlagOverridesPersistor {
    func value(for flag: FeatureFlag) -> Bool?
    func set(_ value: Bool?, for flag: FeatureFlag)
}

public struct FeatureFlagOverridesUserDefaultsPersistor: FeatureFlagOverridesPersistor {
    public let keyValueStore: KeyValueStoring

    public func value(for flag: FeatureFlag) -> Bool? {
        let key = key(for: flag)
        return keyValueStore.object(forKey: key) as? Bool
    }

    public func set(_ value: Bool?, for flag: FeatureFlag) {
        let key = key(for: flag)
        keyValueStore.set(value, forKey: key)
    }

    private func key(for flag: FeatureFlag) -> String {
        return "localOverride\(flag.rawValue.capitalizedFirstLetter)"
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }
}

public protocol FeatureFlagOverridesHandler {
    func flagDidChange(_ featureFlag: FeatureFlag, isEnabled: Bool)
}

public final class FeatureFlagOverrides {

    private var persistor: FeatureFlagOverridesPersistor
    private var actionHandler: FeatureFlagOverridesHandler

    public convenience init(
        keyValueStore: KeyValueStoring,
        actionHandler: FeatureFlagOverridesHandler
    ) {
        self.init(
            persistor: FeatureFlagOverridesUserDefaultsPersistor(keyValueStore: keyValueStore),
            actionHandler: actionHandler
        )
    }

    public init(
        persistor: FeatureFlagOverridesPersistor,
        actionHandler: FeatureFlagOverridesHandler
    ) {
        self.persistor = persistor
        self.actionHandler = actionHandler
    }

    public func toggleOverride(for featureFlag: FeatureFlag) {
        switch featureFlag {
        case .htmlNewTabPage:
            break
        default:
            return
        }

        let currentValue = persistor.value(for: featureFlag) ?? false
        let newValue = !currentValue
        persistor.set(newValue, for: featureFlag)
        actionHandler.flagDidChange(featureFlag, isEnabled: newValue)
    }

    public func override(for featureFlag: FeatureFlag) -> Bool? {
        switch featureFlag {
        case .htmlNewTabPage:
            return persistor.value(for: featureFlag)
        default:
            return nil
        }
    }

    public func clearAllOverrides() {
//        FeatureFlag.allCases.forEach { flag in
//            guard let override = override(for: flag) else {
//                return
//            }
//            persistor.set(nil, for: flag)
//            let defaultValue = featureFlagger.isFeatureOn(flag)
//            if defaultValue != override {
//                actionHandler.flagDidChange(flag, isEnabled: defaultValue)
//            }
//        }
    }
}
