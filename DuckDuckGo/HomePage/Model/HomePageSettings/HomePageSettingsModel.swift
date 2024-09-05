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
import os.log
import PixelKit
import SwiftUI
import SwiftUIExtensions

extension HomePage.Models {

    final class SettingsModel: ObservableObject {

        enum ContentType: Equatable {
            case root
            case gradientPicker
            case colorPicker
            case illustrationPicker
        }

        struct CustomBackgroundModeModel: Identifiable, Hashable {
            let contentType: ContentType
            let title: String
            let customBackgroundThumbnail: CustomBackground?

            var id: String {
                title
            }
        }

        let appearancePreferences: AppearancePreferences
        let sendPixel: (PixelKitEvent) -> Void
        let openSettings: () -> Void

        convenience init(openSettings: @escaping () -> Void) {
            self.init(
                appearancePreferences: .shared,
                sendPixel: { pixelEvent in
                    PixelKit.fire(pixelEvent)
                },
                openSettings: openSettings
            )
        }

        init(
            appearancePreferences: AppearancePreferences,
            sendPixel: @escaping (PixelKitEvent) -> Void,
            openSettings: @escaping () -> Void
        ) {
            self.appearancePreferences = appearancePreferences

            customBackground = appearancePreferences.homePageCustomBackground

            self.sendPixel = sendPixel
            self.openSettings = openSettings
        }

        func popToRootView() {
            withAnimation {
                contentType = .root
            }
        }

        func handleRootGridSelection(_ modeModel: CustomBackgroundModeModel) {
            withAnimation {
                contentType = modeModel.contentType
            }
        }

        @Published private(set) var contentType: ContentType = .root

        @Published var customBackground: CustomBackground? {
            didSet {
                appearancePreferences.homePageCustomBackground = customBackground
                if let customBackground {
                    Logger.homePageSettings.debug("Home page background updated: \(customBackground), color scheme: \(customBackground.colorScheme)")
                } else {
                    Logger.homePageSettings.debug("Home page background reset")
                }
                switch customBackground {
                case .gradient:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedGradient)
                case .solidColor:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor)
                case .illustration:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedIllustration)
                case .none:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundReset)
                }
            }
        }

        var customBackgroundModes: [CustomBackgroundModeModel] {
            [
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .colorPicker),
                customBackgroundModeModel(for: .illustrationPicker)
            ]
        }

        private func customBackgroundModeModel(for contentType: ContentType) -> CustomBackgroundModeModel {
            switch contentType {
            case .root:
                assertionFailure("\(#function) must not be called for ContentType.root")
                return CustomBackgroundModeModel(contentType: .root, title: "", customBackgroundThumbnail: nil)
            case .gradientPicker:
                return CustomBackgroundModeModel(
                    contentType: .gradientPicker,
                    title: UserText.gradients,
                    customBackgroundThumbnail: .gradient(customBackground?.gradient ?? CustomBackground.placeholderGradient)
                )
            case .colorPicker:
                return CustomBackgroundModeModel(
                    contentType: .colorPicker,
                    title: UserText.solidColors,
                    customBackgroundThumbnail: .solidColor(customBackground?.solidColor ?? CustomBackground.placeholderColor)
                )
            case .illustrationPicker:
                return CustomBackgroundModeModel(
                    contentType: .illustrationPicker,
                    title: UserText.illustrations,
                    customBackgroundThumbnail: .illustration(customBackground?.illustration ?? CustomBackground.placeholderIllustration)
                )
            }
        }
    }
}
