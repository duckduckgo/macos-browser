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
import SwiftUIExtensions

protocol ColorSchemeProviding {
    var colorScheme: ColorScheme { get }
}

extension HomePage.Models {

    final class SettingsModel: ObservableObject {

        enum Const {
            static let maximumNumberOfUserImages = 4
        }

        enum ContentType: Equatable {
            case root
            case gradientPicker
            case colorPicker
            case illustrationPicker
            case customImagePicker
        }

        let appearancePreferences: AppearancePreferences
        let customImagesManager: UserBackgroundImagesManaging

        init(
            appearancePreferences: AppearancePreferences = .shared,
            userBackgroundImagesManager: UserBackgroundImagesManaging = UserBackgroundImagesManager(
                maximumNumberOfImages: Const.maximumNumberOfUserImages,
                applicationSupportDirectory: URL.sandboxApplicationSupportURL
            )
        ) {
            self.appearancePreferences = appearancePreferences
            self.customImagesManager = userBackgroundImagesManager
        }

        @Published var contentType: ContentType = .root
        @Published var customBackground: CustomBackground?
        @Published var usesLegacyBlur: Bool = true
        @Published var vibrancyMaterial: VibrancyMaterial = .ultraThinMaterial
        @Published var legacyVibrancyMaterial: NSVisualEffectView.Material = .hudWindow
        @Published var vibrancyAlpha: CGFloat = 1.0

        @ViewBuilder
        var backgroundView: some View {
            if let customBackground {

                switch customBackground {
                case .gradient(let gradient):
                    gradient.image.resizable().aspectRatio(contentMode: .fill)
                        .animation(.none, value: contentType)
                case .illustration(let illustration):
                    illustration.image.resizable().aspectRatio(contentMode: .fill)
                        .animation(.none, value: contentType)
                case .solidColor(let solidColor):
                    solidColor.color
                        .animation(.none, value: contentType)
                case .customImage(let userBackgroundImage):
                    if let nsImage = customImagesManager.image(for: userBackgroundImage) {
                        Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill)
                            .animation(.none, value: contentType)
                    } else {
                        Color.newTabPageBackground
                    }
                }
            } else {
                Color.newTabPageBackground
            }
        }

        @ViewBuilder
        var preview: some View {
            switch customBackground {
            case .gradient(let gradient):
                gradient.image.resizable()
            case .solidColor(let solidColor):
                solidColor.color
            case .illustration(let illustration):
                illustration.image.resizable()
            case .customImage(let userBackgroundImage):
                if let nsImage = customImagesManager.image(for: userBackgroundImage) {
                    Image(nsImage: nsImage).resizable()
                } else {
                    CustomBackground.placeholderCustomImage
                }
            case .none:
                EmptyView()
            }
        }

        @ViewBuilder
        func backgroundPreview(for backgroundType: CustomBackgroundType) -> some View {
            switch backgroundType {
            case .gradient:
                if case let .gradient(gradient) = customBackground {
                    gradient.image.resizable()
                } else {
                    CustomBackground.placeholderGradient
                }
            case .solidColor:
                if case let .solidColor(solidColor) = customBackground {
                    solidColor.color
                } else {
                    CustomBackground.placeholderColor
                }
            case .illustration:
                if case let .illustration(illustration) = customBackground {
                    illustration.image.resizable()
                } else {
                    CustomBackground.placeholderIllustration
                }
            case .customImage:
                if case let .customImage(userBackgroundImage) = customBackground, let nsImage = customImagesManager.image(for: userBackgroundImage) {
                    Image(nsImage: nsImage).resizable()
                } else if let lastUsedUserBackgroundImage = customImagesManager.availableImages.first,
                          let nsImage = customImagesManager.image(for: lastUsedUserBackgroundImage)
                {
                    Image(nsImage: nsImage).resizable()
                } else {
                    CustomBackground.placeholderCustomImage
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
                CustomBackground.placeholderGradient
            case .solidColor:
                CustomBackground.placeholderColor
            case .illustration:
                CustomBackground.placeholderIllustration
            case .customImage:
                CustomBackground.placeholderCustomImage
            }
        }
    }

    enum CustomBackground: Equatable, ColorSchemeProviding {
        case gradient(Gradient)
        case solidColor(SolidColor)
        case illustration(Illustration)
        case customImage(UserBackgroundImage)

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

        static let placeholderGradient: some View = Gradient.gradient03.image.resizable()
        static let placeholderColor: some View = SolidColor.lightPurple.color
        static let placeholderIllustration: some View = Illustration.illustration01.image.resizable()
        static let placeholderCustomImage: some View = SolidColor.gray.color
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

    struct CustomImage: Equatable, Identifiable, ColorSchemeProviding {
        let name: String
        let colorScheme: ColorScheme

        var id: String {
            name
        }
    }
}
