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

/**
 * This protocol describes types that determine color scheme to be used in the UI.
 *
 * It's implemented by various custom backgrounds, allowing them to fix color scheme
 * of the New Tab Page to either light or dark, regardless of the system theme
 * or browser appearance settings.
 */
protocol ColorSchemeProviding {
    var colorScheme: ColorScheme { get }
}

/**
 * This protocol describes types that can be converted to `CustomBackground`.
 *
 * These are essentially all available custom background types. The `customBackground`
 * property returns the given custom background type wrapped in a `CustomBackground` enum case.
 */
protocol CustomBackgroundConvertible {
    var customBackground: CustomBackground { get }
}

/**
 * This enum represents custom New Tab Page background.
 *
 * 3 types of backgrounds are available at the moment:
 * - gradient – uses predefined gradient images
 * - solid color – uses predefined colors
 * - user image – uses images uploaded by the user.
 */
enum CustomBackground: Equatable, Hashable, ColorSchemeProviding, LosslessStringConvertible {

    static let placeholderGradient: GradientBackground = .gradient03
    static let placeholderColor: SolidColorBackground = .color07

    case gradient(GradientBackground)
    case solidColor(SolidColorBackground)
    case userImage(UserBackgroundImage)

    var gradient: GradientBackground? {
        guard case let .gradient(gradient) = self else {
            return nil
        }
        return gradient
    }

    var solidColor: SolidColorBackground? {
        guard case let .solidColor(solidColor) = self else {
            return nil
        }
        return solidColor
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

        let backgroundType = String(components[0])
        let backgroundValue = String(components[1])

        switch backgroundType {
        case "gradient":
            guard let gradient = GradientBackground(rawValue: backgroundValue) else {
                return nil
            }
            self = .gradient(gradient)
        case "solidColor":
            guard let solidColor = SolidColorBackground(backgroundValue) else {
                return nil
            }
            self = .solidColor(solidColor)
        case "userImage":
            guard let userBackgroundImage = UserBackgroundImage(backgroundValue) else {
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
            "solidColor|\(solidColor.description)"
        case let .userImage(userBackgroundImage):
            "userImage|\(userBackgroundImage.description)"
        }
    }
}
