//
//  UserDefaults+NetworkProtectionShared.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation
import NetworkProtectionUI

extension UserDefaults {
    // Convenience declaration
    var networkProtectionOnboardingStatusRawValueKey: String {
        UserDefaultsWrapper<Any>.Key.networkProtectionOnboardingStatusRawValue.rawValue
    }

    /// For KVO to work across processes (Menu App + Main App) we need to declare this dynamic var in a `UserDefaults`
    /// extension, and the key for this property must match its name exactly.
    ///
    @objc
    dynamic var networkProtectionOnboardingStatusRawValue: String {
        get {
            value(forKey: networkProtectionOnboardingStatusRawValueKey) as? String ?? OnboardingStatus.default.rawValue
        }

        set {
            set(newValue, forKey: networkProtectionOnboardingStatusRawValueKey)
        }
    }

    var networkProtectionOnboardingStatus: OnboardingStatus {
        get {
            OnboardingStatus(rawValue: networkProtectionOnboardingStatusRawValue) ?? .default
        }

        set {
            networkProtectionOnboardingStatusRawValue = newValue.rawValue
        }
    }

    var networkProtectionOnboardingStatusPublisher: AnyPublisher<OnboardingStatus, Never> {
        // It's important to subscribe to the publisher for the raw value, since this
        // is the way to get KVO when the UserDefaults are modified by another process.
        publisher(for: \.networkProtectionOnboardingStatusRawValue).map { value in
            OnboardingStatus(rawValue: value) ?? .default
        }.eraseToAnyPublisher()
    }
}

extension NetworkProtectionUI.OnboardingStatus {
    /// The default onboarding status.
    ///
    /// This default is defined in our browser app because it's inherently tied to the specific build-configuration of the browser
    /// app:
    /// - For AppStore builds the default is asking the user to allow the VPN configuration.
    /// - For DeveloperID builds the default is asking the user to allow the System Extension.
    ///
    public static let `default`: OnboardingStatus = {
#if NETP_SYSTEM_EXTENSION
        .isOnboarding(step: .userNeedsToAllowExtension)
#else
        .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
#endif
    }()
}
