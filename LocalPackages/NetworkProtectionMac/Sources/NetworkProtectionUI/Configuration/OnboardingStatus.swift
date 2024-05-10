//
//  OnboardingStatus.swift
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

public typealias OnboardingStatusPublisher = AnyPublisher<OnboardingStatus, Never>

/// Whether the user is onboarding.
///
@frozen
public enum OnboardingStatus: RawRepresentable, Equatable {

    /// The onboarding has been completed at least once
    ///
    case completed

    case isOnboarding(step: OnboardingStep)

    static let notStartedRawValue = "notStarted"
    static let completedRawValue = "completed"
    static let isOnboardingRawValue = "isOnboarding."

    public init?(rawValue: String) {
        if rawValue == Self.completedRawValue {
            self = .completed
            return
        } else if rawValue.hasPrefix(Self.isOnboardingRawValue) {
            let stepRawValue = rawValue.dropping(prefix: Self.isOnboardingRawValue)

            guard let step = OnboardingStep(rawValue: stepRawValue) else {
                return nil
            }

            self = .isOnboarding(step: step)
            return
        }

        return nil
    }

    public var rawValue: String {
        switch self {
        case .completed:
            return Self.completedRawValue
        case .isOnboarding(let step):
            return Self.isOnboardingRawValue + step.rawValue
        }
    }
}

/// A specific step in the onboarding process.
///
@frozen
public enum OnboardingStep: String, Equatable {
    /// The user needs to allow the system extension in macOS
    ///
    case userNeedsToAllowExtension

    /// The user needs to allow the VPN Configuration creation
    ///
    case userNeedsToAllowVPNConfiguration
}
