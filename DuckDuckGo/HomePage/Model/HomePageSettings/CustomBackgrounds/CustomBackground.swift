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

enum CustomBackground: Equatable, Hashable, ColorSchemeProviding, LosslessStringConvertible {

    static let placeholderGradient: Gradient = .gradient03
    static let placeholderColor: SolidColor = .lightPurple
    static let placeholderIllustration: Illustration = .illustration01
    static let placeholderCustomImage: SolidColor = .gray

    case gradient(Gradient)
    case solidColor(SolidColor)
    case illustration(Illustration)
    case userImage(UserBackgroundImage)

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
        guard case let .userImage(image) = self else {
            return nil
        }
        return image
    }

    var colorScheme: ColorScheme {
        switch self {
        case .gradient(let gradient):
            gradient.colorScheme
        case .illustration(let illustration):
            illustration.colorScheme
        case .solidColor(let solidColor):
            solidColor.colorScheme
        case .userImage(let image):
            image.colorScheme
        }
    }

    // MARK: - LosslessStringConvertible

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
        case "userImage":
            guard let userBackgroundImage = UserBackgroundImage(String(components[1])) else {
                return nil
            }
            self = .userImage(userBackgroundImage)
        default:
            return nil
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
        case let .userImage(userBackgroundImage):
            "userImage|\(userBackgroundImage.description)"
        }
    }
}
