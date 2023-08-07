//
//  UserDefaultPublisher.swift
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
    var networkProtectionOnboardingStatusKey: String {
        UserDefaultsWrapper<Any>.Key.networkProtectionOnboardingStatus.rawValue
    }

    /// For KVO to work across processes (Menu App + Main App) we need to declare this dynamic var in a `UserDefaults`
    /// extension, and the key for this property must match its name exactly.
    ///
    @objc
    dynamic var networkProtectionOnboardingStatus: Int {
        get {
            value(forKey: networkProtectionOnboardingStatusKey) as? Int ?? OnboardingStatus.default.rawValue
        }

        set {
            set(newValue, forKey: networkProtectionOnboardingStatusKey)
        }
    }

    var networkProtectionOnboardingStatusPublisher: AnyPublisher<OnboardingStatus, Never> {
        publisher(for: \.networkProtectionOnboardingStatus).map { value in
            OnboardingStatus(rawValue: value) ?? .default
        }.eraseToAnyPublisher()
    }
}
