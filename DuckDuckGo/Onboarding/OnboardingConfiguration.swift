//
//  OnboardingConfiguration.swift
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

import Foundation

/// Configuration needed to set up the FE onboarding
struct OnboardingConfiguration: Codable, Equatable {
    var stepDefinitions: StepDefinitions
    var exclude: [String]
    var order: String
    var env: String
    var locale: String
    var platform: OnboardingPlatform
}

/// Defines the onboarding steps desired
struct StepDefinitions: Codable, Equatable {
    var systemSettings: SystemSettings
}

struct SystemSettings: Codable, Equatable {
    var rows: [String]
}

struct OnboardingPlatform: Codable, Equatable {
    var name: String
}

struct OnboardingImportResponse: Codable, Equatable {
    var enabled: Bool
}
