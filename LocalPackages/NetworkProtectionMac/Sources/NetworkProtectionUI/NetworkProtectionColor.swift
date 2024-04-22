//
//  NetworkProtectionColor.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI

extension Color {
    /// Convenience initializer to make it easier to use our custom colors.
    ///
    init(_ networkProtectionColor: NetworkProtectionColor) {
        self = networkProtectionColor.asColor
    }
}

/// NetworkProtectionUI bundled color definitions
///
enum NetworkProtectionColor: String {
    case defaultText = "TextColor"
    case secondaryText = "SecondaryColor"
    case linkColor = "LinkBlueColor"
    case onboardingButtonBackgroundColor = "OnboardingButtonBackgroundColor"
#if swift(<5.9)
    case alertBubbleBackground = "AlertBubbleBackground"
    case onboardingStepBorder = "OnboardingStepBorderColor"
    case onboardingStepBackground = "OnboardingStepBackgroundColor"
#endif

    var asColor: Color {
        Color(rawValue, bundle: .module)
    }
}
