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
            case uploadImage

            var customBackgroundType: CustomBackgroundType? {
                switch self {
                case .gradientPicker:
                        .gradient
                case .colorPicker:
                        .solidColor
                case .illustrationPicker:
                        .illustration
                case .customImagePicker:
                        .customImage
                case .root, .uploadImage:
                    nil
                }
            }
        }

        struct BackgroundModeModel: Identifiable, Hashable {
            let contentType: ContentType
            let title: String
            let customBackgroundPreview: CustomBackground?

            var id: String {
                title
            }
        }

        let appearancePreferences: AppearancePreferences
        let customImagesManager: UserBackgroundImagesManaging
        let openURL: (URL) -> Void
        init(
            appearancePreferences: AppearancePreferences = .shared,
            userBackgroundImagesManager: UserBackgroundImagesManaging = UserBackgroundImagesManager(
                maximumNumberOfImages: Const.maximumNumberOfUserImages,
                applicationSupportDirectory: URL.sandboxApplicationSupportURL
            ),
            openURL: @escaping (URL) -> Void
        ) {
            self.appearancePreferences = appearancePreferences
            self.customImagesManager = userBackgroundImagesManager
            customBackground = appearancePreferences.homePageCustomBackground
            self.openURL = openURL
        }

        @Published var contentType: ContentType = .root {
            didSet {
                if contentType == .uploadImage, contentType != oldValue {
                    contentType = .root
                    uploadNewImage()
                }
            }
        }
        @Published var customBackground: CustomBackground? {
            didSet {
                appearancePreferences.homePageCustomBackground = customBackground
            }
        }
        @Published var usesLegacyBlur: Bool = true
        @Published var vibrancyMaterial: VibrancyMaterial = .ultraThinMaterial
        @Published var legacyVibrancyMaterial: NSVisualEffectView.Material = .fullScreenUI
        @Published var vibrancyAlpha: CGFloat = 1.0

        func uploadNewImage() {
            let panel = NSOpenPanel(allowedFileTypes: [.image])
            guard case .OK = panel.runModal(), let url = panel.url else {
                return
            }
            Task {
                if let image = try? await customImagesManager.addImage(with: url) {
                    Task { @MainActor in
                        customBackground = .customImage(image)
                    }
                }
            }
        }

        var backgroundModes: [BackgroundModeModel] {
            var modes: [BackgroundModeModel] = [
                .init(contentType: .gradientPicker, title: "Gradients", customBackgroundPreview: .gradient(customBackground?.gradient ?? CustomBackground.placeholderGradient)),
                .init(contentType: .colorPicker, title: "Solid Colors", customBackgroundPreview: .solidColor(customBackground?.solidColor ?? CustomBackground.placeholderColor)),
                .init(contentType: .illustrationPicker, title: "Illustrations", customBackgroundPreview: .illustration(customBackground?.illustration ?? CustomBackground.placeholderIllustration))
            ]
            if customImagesManager.availableImages.count > 0 {
                let preview: CustomBackground? = {
                    guard customBackground?.userBackgroundImage == nil else {
                        return customBackground
                    }
                    guard let lastUsedUserBackgroundImage = customImagesManager.availableImages.first else {
                        return nil
                    }
                    return .customImage(lastUsedUserBackgroundImage)
                }()
                modes.append(.init(contentType: .customImagePicker, title: "Custom Images", customBackgroundPreview: preview))
            }
            modes.append(.init(contentType: .uploadImage, title: "Upload Image", customBackgroundPreview: nil))
            return modes
        }

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
    }

    enum CustomBackground: Equatable, Hashable, ColorSchemeProviding, LosslessStringConvertible {
        init?(_ description: String) {
            let components = description.components(separatedBy: "|")
            guard components.count == 2 else {
                return nil
            }
            switch components[0] {
            case "gradient":
                guard let gradient = Gradient(rawValue: components[1]) else {
                    return nil
                }
                self = .gradient(gradient)
            case "solidColor":
                guard let solidColor = SolidColor(rawValue: components[1]) else {
                    return nil
                }
                self = .solidColor(solidColor)
            case "illustration":
                guard let illustration = Illustration(rawValue: components[1]) else {
                    return nil
                }
                self = .illustration(illustration)
            case "customImage":
                guard let userBackgroundImage = UserBackgroundImage(components[1]) else {
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

        static let placeholderGradient: Gradient = .gradient03
        static let placeholderColor: SolidColor = .lightPurple
        static let placeholderIllustration: Illustration = .illustration01
        static let placeholderCustomImage: SolidColor = .gray
    }

    enum Gradient: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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

    enum Illustration: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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

    enum SolidColor: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding {
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
