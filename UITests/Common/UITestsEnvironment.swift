//
//  UITestsEnvironment.swift
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

#if CI || DEBUG || REVIEW

enum UITestEnvironmentKey: String {
    case onboardingFinished = "UI-TESTS-ONBOARDING-DID-RUN"
    case disableOnboardingAnimations = "UI-TESTS-DISABLE-ONBOARDING-ANIMATIONS"

    case suppressMoveToApplications = "UI-TESTS-SUPPRESS-MOVE-TO-APPLICATIONS"
    case resetSavedState = "UI-TESTS-RESET-SAVED-STATE"
    case shouldRestorePreviousSession = "UI-TESTS-RESTORE-PREVIOUS-SESSION"

}
enum UITestEnvironmentValue: String {
    case `true` = "1"
    case `false` = "0"

    var boolValue: Bool {
        switch self {
        case .true: true
        case .false: false
        }
    }
}

extension ProcessInfo {

    var uiTestsEnvironment: [UITestEnvironmentKey: UITestEnvironmentValue] {
        self.environment.reduce(into: [:]) { (result, item) in
            if let key = UITestEnvironmentKey(rawValue: item.key),
               let value = UITestEnvironmentValue(rawValue: item.value) {
                result[key] = value
            }
        }
    }

}

#endif
