//
//  SolidColorBackground.swift
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

enum SolidColorBackground: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Self {
        self
    }

    case lightPink
    case darkPink
    case lightOrange
    case darkOrange
    case lightYellow
    case darkYellow
    case lightGreen
    case darkGreen
    case lightBlue
    case darkBlue
    case lightPurple
    case darkPurple
    case gray
    case black

    var color: Color {
        switch self {
        case .gray:
                .homePageBackgroundGray
        case .black:
                .homePageBackgroundBlack
        case .lightPink:
                .homePageBackgroundLightPink
        case .lightOrange:
                .homePageBackgroundLightOrange
        case .lightYellow:
                .homePageBackgroundLightYellow
        case .lightGreen:
                .homePageBackgroundLightGreen
        case .lightBlue:
                .homePageBackgroundLightBlue
        case .lightPurple:
                .homePageBackgroundLightPurple
        case .darkPink:
                .homePageBackgroundDarkPink
        case .darkOrange:
                .homePageBackgroundDarkOrange
        case .darkYellow:
                .homePageBackgroundDarkYellow
        case .darkGreen:
                .homePageBackgroundDarkGreen
        case .darkBlue:
                .homePageBackgroundDarkBlue
        case .darkPurple:
                .homePageBackgroundDarkPurple
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .gray, .lightPink, .lightOrange, .lightYellow, .darkYellow, .lightGreen, .lightBlue, .lightPurple:
                .light
        case .black, .darkPink, .darkOrange, .darkGreen, .darkBlue, .darkPurple:
                .dark
        }
    }

    var customBackground: CustomBackground {
        .solidColor(self)
    }
}
