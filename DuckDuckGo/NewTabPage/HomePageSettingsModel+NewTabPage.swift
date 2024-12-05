//
//  HomePageSettingsModel+NewTabPage.swift
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

import NewTabPage
import SwiftUI

final class NewTabPageCustomizationProvider: NewTabPageCustomBackgroundProviding {
    let homePageSettingsModel: HomePage.Models.SettingsModel
    let appearancePreferences: AppearancePreferences

    init(homePageSettingsModel: HomePage.Models.SettingsModel, appearancePreferences: AppearancePreferences = .shared) {
        self.homePageSettingsModel = homePageSettingsModel
        self.appearancePreferences = appearancePreferences
    }

    var customizerData: NewTabPageUserScript.CustomizerData {
        .init(
            background: .init(homePageSettingsModel.customBackground),
            theme: .init(appearancePreferences.currentThemeName),
            userImages: homePageSettingsModel.availableUserBackgroundImages.map(NewTabPageUserScript.UserImage.init)
        )
    }
}

extension NewTabPageUserScript.Background {
    init(_ customBackground: CustomBackground?) {
        switch customBackground {
        case .gradient(let gradient):
            self = .gradient(gradient.rawValue)
        case .solidColor(let solidColor):
            if let predefinedColorName = solidColor.predefinedColorName {
                self = .solidColor(predefinedColorName)
            } else {
                self = .hexColor(solidColor.description)
            }
        case .userImage(let userBackgroundImage):
            self = .userImage(.init(userBackgroundImage))
        case .none:
            self = .default
        }
    }
}

extension NewTabPageUserScript.UserImage {
    init(_ userBackgroundImage: UserBackgroundImage) {
        self.init(
            colorScheme: .init(userBackgroundImage.colorScheme),
            id: userBackgroundImage.id,
            src: "/background/images/\(userBackgroundImage.fileName)",
            thumb: "/background/thumbnails/\(userBackgroundImage.fileName)"
        )
    }
}

extension NewTabPageUserScript.Theme {
    init(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            self = .dark
        case .light:
            self = .light
        @unknown default:
            self = .light
        }
    }

    init?(_ themeName: ThemeName) {
        switch themeName {
        case .light:
            self = .light
        case .dark:
            self = .dark
        case .systemDefault:
            return nil
        }
    }
}

extension URL {
    static func duckUserBackgroundImage(for fileName: String) -> URL? {
        return URL(string: "duck://user-background-image/\(fileName)")
    }

    static func duckUserBackgroundImageThumbnail(for fileName: String) -> URL? {
        return URL(string: "duck://user-background-image/thumbnails/\(fileName)")
    }
}
