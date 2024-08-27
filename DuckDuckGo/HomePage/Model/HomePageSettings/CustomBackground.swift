//
//  CustomBackground.swift
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
import SwiftUI

protocol ColorSchemeProviding {
    var colorScheme: ColorScheme { get }
}

protocol CustomBackgroundConvertible {
    var customBackground: CustomBackground { get }
}

enum CustomBackgroundType {
    case gradient, solidColor, illustration, customImage
}

enum CustomBackground: Equatable, Hashable, ColorSchemeProviding, LosslessStringConvertible {
    init?(_ description: String) {
        let components = description.split(separator: "|", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }
        switch components[0] {
        case "gradient":
            guard let gradient = Gradient(rawValue: String(components[1])) else {
                return nil
            }
            self = .gradient(gradient)
        case "solidColor":
            guard let solidColor = SolidColor(rawValue: String(components[1])) else {
                return nil
            }
            self = .solidColor(solidColor)
        case "illustration":
            guard let illustration = Illustration(rawValue: String(components[1])) else {
                return nil
            }
            self = .illustration(illustration)
        case "customImage":
            guard let userBackgroundImage = UserBackgroundImage(String(components[1])) else {
                return nil
            }
            self = .customImage(userBackgroundImage)
        default:
            return nil
        }
    }

    var customBackgroundType: CustomBackgroundType {
        switch self {
        case .gradient:
                .gradient
        case .solidColor:
                .solidColor
        case .illustration:
                .illustration
        case .customImage:
                .customImage
        }
    }

    var description: String {
        switch self {
        case let .gradient(gradient):
            "gradient|\(gradient.rawValue)"
        case let .solidColor(solidColor):
            "solidColor|\(solidColor.rawValue)"
        case let .illustration(illustration):
            "illustration|\(illustration.rawValue)"
        case let .customImage(userBackgroundImage):
            "customImage|\(userBackgroundImage.description)"
        }
    }

    case gradient(Gradient)
    case solidColor(SolidColor)
    case illustration(Illustration)
    case customImage(UserBackgroundImage)

    var colorScheme: ColorScheme {
        switch self {
        case .gradient(let gradient):
            gradient.colorScheme
        case .illustration(let illustration):
            illustration.colorScheme
        case .solidColor(let solidColor):
            solidColor.colorScheme
        case .customImage(let image):
            image.colorScheme
        }
    }

    var gradient: Gradient? {
        guard case let .gradient(gradient) = self else {
            return nil
        }
        return gradient
    }

    var solidColor: SolidColor? {
        guard case let .solidColor(solidColor) = self else {
            return nil
        }
        return solidColor
    }

    var illustration: Illustration? {
        guard case let .illustration(illustration) = self else {
            return nil
        }
        return illustration
    }

    var userBackgroundImage: UserBackgroundImage? {
        guard case let .customImage(image) = self else {
            return nil
        }
        return image
    }

    static let placeholderGradient: Gradient = .gradient03
    static let placeholderColor: SolidColor = .lightPurple
    static let placeholderIllustration: Illustration = .illustration01
    static let placeholderCustomImage: SolidColor = .gray
}

enum Gradient: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Self {
        self
    }

    case gradient01
    case gradient02
    case gradient03
    case gradient04
    case gradient05
    case gradient06
    case gradient07

    var image: Image {
        switch self {
        case .gradient01:
            Image(nsImage: .homePageBackgroundGradient01)
        case .gradient02:
            Image(nsImage: .homePageBackgroundGradient02)
        case .gradient03:
            Image(nsImage: .homePageBackgroundGradient03)
        case .gradient04:
            Image(nsImage: .homePageBackgroundGradient04)
        case .gradient05:
            Image(nsImage: .homePageBackgroundGradient05)
        case .gradient06:
            Image(nsImage: .homePageBackgroundGradient06)
        case .gradient07:
            Image(nsImage: .homePageBackgroundGradient07)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .gradient01, .gradient02, .gradient03:
                .light
        case .gradient04, .gradient05, .gradient06, .gradient07:
                .dark
        }
    }

    var customBackground: CustomBackground {
        .gradient(self)
    }
}

enum Illustration: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
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

enum SolidColor: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
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
        case .gray, .lightPink, .lightOrange, .lightYellow, .lightGreen, .lightBlue, .lightPurple:
                .light
        case .black, .darkPink, .darkOrange, .darkYellow, .darkGreen, .darkBlue, .darkPurple:
                .dark
        }
    }

    var customBackground: CustomBackground {
        .solidColor(self)
    }
}

struct UserBackgroundImage: Hashable, Equatable, Identifiable, LosslessStringConvertible, ColorSchemeProviding, CustomBackgroundConvertible {
    let fileName: String
    let colorScheme: ColorScheme

    var id: String {
        fileName
    }

    var customBackground: CustomBackground {
        .customImage(self)
    }

    var description: String {
        "\(fileName)|\(colorScheme.description)"
    }

    init(fileName: String, colorScheme: ColorScheme) {
        self.fileName = fileName
        self.colorScheme = colorScheme
    }

    init?(_ description: String) {
        let components = description.split(separator: "|", maxSplits: 1)
        guard components.count == 2, let colorScheme = ColorScheme(String(components[1])) else {
            return nil
        }
        self.fileName = String(components[0])
        self.colorScheme = colorScheme
    }
}
