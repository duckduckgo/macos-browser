//
//  PrivacySecurityPreferences.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation
import Combine

final class PrivacySecurityPreferences {
    static let shared = PrivacySecurityPreferences()

    private init() {}

    @UserDefaultsWrapper(key: .loginDetectionEnabled, defaultValue: true)
    var loginDetectionEnabled: Bool

    @Published
    var gpcEnabled: Bool = UserDefaultsWrapper(key: .gpcEnabled, defaultValue: true).wrappedValue {
        didSet {
            var udWrapper = UserDefaultsWrapper(key: .gpcEnabled, defaultValue: true)
            udWrapper.wrappedValue = gpcEnabled
        }
    }

    // This setting is an optional boolean as it has three states:
    // - nil: User has not chosen a setting
    // - true: Enabled by the user
    // - false: Disabled by the user
    @UserDefaultsWrapper(key: .autoconsentEnabled, defaultValue: nil)
    public var autoconsentEnabled: Bool?

    @UserDefaultsWrapper(key: .privateYoutubePlayerEnabled, defaultValue: false)
    var privateYoutubePlayerEnabled: Bool
}
