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

    public init?(rawValue: Int) {
        if rawValue == 0 {
            self = .completed
            return
        }

        let stepValue = rawValue - 1
        guard let step = OnboardingStep(rawValue: stepValue) else {
            return nil
        }

        self = .isOnboarding(step: step)
    }

    public var rawValue: Int {
        switch self {
        case .completed:
            return 0
        case .isOnboarding(let step):
            return 1 + step.rawValue
        }
    }
}

/// A specific step in the onboarding process.
///
@frozen
public enum OnboardingStep: Int, Equatable {
    /// The user needs to allow the system extension in macOS
    ///
    case userNeedsToAllowExtension

    /// The user needs to allow the VPN Configuration creation
    ///
    case userNeedsToAllowVPNConfiguration
}
