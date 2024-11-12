//
//  OverridableFeatureFlagger.swift
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

public final class OverridableFeatureFlagger: FeatureFlagger {

    public let defaultFlagger: DefaultFeatureFlagger
    public let overrides: FeatureFlagOverrides

    public init(defaultFlagger: DefaultFeatureFlagger, overrides: FeatureFlagOverrides) {
        self.defaultFlagger = defaultFlagger
        self.overrides = overrides
    }

    public func isFeatureOn<F: FeatureFlagSourceProviding>(forProvider provider: F) -> Bool {
        defaultFlagger.isFeatureOn(forProvider: provider)
    }

    public func isFeatureOn(_ featureFlag: FeatureFlag, allowOverride: Bool = true) -> Bool {
        if defaultFlagger.internalUserDecider.isInternalUser, allowOverride, let localOverride = overrides.override(for: featureFlag) {
            return localOverride
        }
        return isFeatureOn(forProvider: featureFlag)
    }
}

public extension FeatureFlagger {

    func isFeatureOn(_ featureFlag: FeatureFlag) -> Bool {
        if let overridableFlagger = self as? OverridableFeatureFlagger {
            return overridableFlagger.isFeatureOn(featureFlag, allowOverride: true)
        }
        return isFeatureOn(forProvider: featureFlag)
    }
}
