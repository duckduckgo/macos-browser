//
//  IllustrationBackground.swift
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

import AppKit
import SwiftUI

enum IllustrationBackground: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Self {
        self
    }

    case illustration01
    case illustration02
    case illustration03
    case illustration04
    case illustration05
    case illustration06

    var image: Image {
        switch self {
        case .illustration01:
            Image(nsImage: .homePageBackgroundIllustration01)
        case .illustration02:
            Image(nsImage: .homePageBackgroundIllustration02)
        case .illustration03:
            Image(nsImage: .homePageBackgroundIllustration03)
        case .illustration04:
            Image(nsImage: .homePageBackgroundIllustration04)
        case .illustration05:
            Image(nsImage: .homePageBackgroundIllustration05)
        case .illustration06:
            Image(nsImage: .homePageBackgroundIllustration06)
        }
    }

    var colorScheme: ColorScheme {
        .light
    }

    var customBackground: CustomBackground {
        .illustration(self)
    }
}
