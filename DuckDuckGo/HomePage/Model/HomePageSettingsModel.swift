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

import Combine
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
                case .root:
                    nil
                }
            }
        }

        struct CustomBackgroundModeModel: Identifiable, Hashable {
            let contentType: ContentType
            let title: String
            let customBackgroundPreview: CustomBackground?

            var id: String {
                title
            }
        }

        let appearancePreferences: AppearancePreferences
        let customImagesManager: UserBackgroundImagesManaging
        let openSettings: () -> Void

        @Published private(set) var availableUserBackgroundImages: [UserBackgroundImage] = []

        private var availableCustomImagesCancellable: AnyCancellable?

        init(
            appearancePreferences: AppearancePreferences = .shared,
            userBackgroundImagesManager: UserBackgroundImagesManaging = UserBackgroundImagesManager(
                maximumNumberOfImages: Const.maximumNumberOfUserImages,
                applicationSupportDirectory: URL.sandboxApplicationSupportURL
            ),
            openSettings: @escaping () -> Void
        ) {
            self.appearancePreferences = appearancePreferences
            self.customImagesManager = userBackgroundImagesManager
            customBackground = appearancePreferences.homePageCustomBackground
            self.openSettings = openSettings

            availableCustomImagesCancellable = customImagesManager.availableImagesPublisher
                .receive(on: DispatchQueue.main)
                .handleEvents(receiveOutput: { [weak self] images in
                    guard case .customImage(let userBackgroundImage) = self?.customBackground, !images.contains(userBackgroundImage) else {
                        return
                    }
                    if let firstImage = images.first {
                        self?.customBackground = .customImage(firstImage)
                    } else {
                        self?.customBackground = nil
                        withAnimation {
                            self?.contentType = .root
                        }
                    }
                })
                .assign(to: \.availableUserBackgroundImages, onWeaklyHeld: self)
        }

        var hasUserImages: Bool {
            !customImagesManager.availableImages.isEmpty
        }

        func popToRootView() {
            withAnimation {
                contentType = .root
            }
        }

        func handleRootGridSelection(_ modeModel: CustomBackgroundModeModel) {
            if modeModel.contentType == .customImagePicker && !hasUserImages {
                addNewImage()
            } else {
                withAnimation {
                    contentType = modeModel.contentType
                }
            }
        }

        @Published private(set) var contentType: ContentType = .root {
            didSet {
                if contentType == .root, oldValue == .customImagePicker {
                    customImagesManager.sortImagesByLastUsed()
                }
            }
        }

        @Published var customBackground: CustomBackground? {
            didSet {
                appearancePreferences.homePageCustomBackground = customBackground
                if case .customImage(let userBackgroundImage) = customBackground {
                    customImagesManager.updateSelectedTimestamp(for: userBackgroundImage)
                }
            }
        }
        @Published var vibrancyMaterial: NSVisualEffectView.Material = .fullScreenUI
        @Published var vibrancyAlpha: CGFloat = 1.0
        @Published var backgroundColorRed: CGFloat = 0.0
        @Published var backgroundColorGreen: CGFloat = 0.0
        @Published var backgroundColorBlue: CGFloat = 0.0
        @Published var backgroundColorAlpha: CGFloat = 0.0
        var backgroundColor: NSColor {
            .init(red: backgroundColorRed, green: backgroundColorGreen, blue: backgroundColorBlue, alpha: backgroundColorAlpha)
        }

        func addNewImage() {
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

        func customBackgroundModeModel(for contentType: ContentType) -> CustomBackgroundModeModel {
            switch contentType {
            case .root:
                assertionFailure("\(#function) must not be called for ContentType.root")
                return CustomBackgroundModeModel(contentType: .root, title: "", customBackgroundPreview: nil)
            case .gradientPicker:
                return CustomBackgroundModeModel(
                    contentType: .gradientPicker,
                    title: "Gradients",
                    customBackgroundPreview: .gradient(customBackground?.gradient ?? CustomBackground.placeholderGradient)
                )
            case .colorPicker:
                return CustomBackgroundModeModel(
                    contentType: .colorPicker,
                    title: "Solid Colors",
                    customBackgroundPreview: .solidColor(customBackground?.solidColor ?? CustomBackground.placeholderColor)
                )
            case .illustrationPicker:
                return CustomBackgroundModeModel(
                    contentType: .illustrationPicker,
                    title: "Illustrations",
                    customBackgroundPreview: .illustration(customBackground?.illustration ?? CustomBackground.placeholderIllustration)
                )
            case .customImagePicker:
                let title = customImagesManager.availableImages.isEmpty ? "Add Background" : "My Backgrounds"
                let preview: CustomBackground? = {
                    guard customBackground?.userBackgroundImage == nil else {
                        return customBackground
                    }
                    guard let lastUsedUserBackgroundImage = customImagesManager.availableImages.first else {
                        return nil
                    }
                    return .customImage(lastUsedUserBackgroundImage)
                }()
                return CustomBackgroundModeModel(contentType: .customImagePicker, title: title, customBackgroundPreview: preview)
            }
        }

        var customBackgroundModes: [CustomBackgroundModeModel] {
            var modes: [CustomBackgroundModeModel] = [
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .colorPicker),
                customBackgroundModeModel(for: .illustrationPicker),
                customBackgroundModeModel(for: .customImagePicker)
            ]
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
    }
}

extension HomePage.Models.SettingsModel {
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
