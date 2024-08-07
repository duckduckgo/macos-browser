//
//  HomePageSettingsModel.swift
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

extension HomePage.Models {

    final class SettingsModel: ObservableObject {

        enum ContentType: Equatable {
            case root
            case gradientPicker
            case colorPicker
            case illustrationPicker
            case customImagePicker
        }

        @Published var contentType: ContentType = .root
        @Published var customBackground: CustomBackground?

        @ViewBuilder
        var backgroundView: some View {
            if let customBackground {
                customBackground.view
            } else {
                Color.newTabPageBackground
            }
        }

        @ViewBuilder
        func backgroundPreview(for backgroundType: CustomBackgroundType) -> some View {
            switch backgroundType {
            case .gradient:
                if isGradientSelected, let preview = customBackground?.preview {
                    preview
                } else {
                    backgroundType.placeholderView
                }
            case .solidColor:
                if isSolidColorSelected, let preview = customBackground?.preview {
                    preview
                } else {
                    backgroundType.placeholderView
                }
            case .illustration:
                if isIllustrationSelected, let preview = customBackground?.preview {
                    preview
                } else {
                    backgroundType.placeholderView
                }
            case .customImage:
                if isCustomImageSelected, let preview = customBackground?.preview {
                    preview
                } else {
                    backgroundType.placeholderView
                }
            }
        }

        var isGradientSelected: Bool {
            guard case .gradient = customBackground else {
                return false
            }
            return true
        }

        var isSolidColorSelected: Bool {
            guard case .solidColor = customBackground else {
                return false
            }
            return true
        }

        var isIllustrationSelected: Bool {
            guard case .illustration = customBackground else {
                return false
            }
            return true
        }

        var isCustomImageSelected: Bool {
            guard case .customImage = customBackground else {
                return false
            }
            return true
        }
    }
}

extension HomePage.Models.SettingsModel {
    enum CustomBackgroundType {
        case gradient, solidColor, illustration, customImage

        @ViewBuilder
        var placeholderView: some View {
            switch self {
            case .gradient:
                CustomBackground.placeholderGradient.preview
            case .solidColor:
                CustomBackground.placeholderColor.preview
            case .illustration:
                CustomBackground.placeholderIllustration.preview
            case .customImage:
                CustomBackground.placeholderCustomImage.preview
            }
        }
    }

    enum CustomBackground: Equatable, ColorSchemeProviding {
        case gradient(Gradient)
        case solidColor(SolidColor)
        case illustration(Illustration)
        case customImage(Image)

        var isSolidColor: Bool {
            guard case .solidColor = self else {
                return false
            }
            return true
        }

        var colorScheme: ColorScheme {
            switch self {
            case .gradient(let gradient):
                gradient.colorScheme
            case .illustration(let illustration):
                illustration.colorScheme
            case .solidColor(let solidColor):
                solidColor.colorScheme
            case .customImage:
                .light
            }
        }

        @ViewBuilder
        var view: some View {
            switch self {
            case .gradient(let gradient):
                gradient.image.resizable().aspectRatio(contentMode: .fill)
            case .illustration(let illustration):
                illustration.image.resizable().aspectRatio(contentMode: .fill)
            case .solidColor(let solidColor):
                solidColor.color
            case .customImage(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            }
        }

        static let placeholderGradient = CustomBackground.gradient(.gradient03)
        static let placeholderColor = CustomBackground.solidColor(.lightPurple)
        static let placeholderIllustration = CustomBackground.illustration(.illustration01)
        static let placeholderCustomImage = CustomBackground.solidColor(.gray)
    }

    enum Gradient: Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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
    }

    enum Illustration: Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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
    }

    enum SolidColor: Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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
    }
}
