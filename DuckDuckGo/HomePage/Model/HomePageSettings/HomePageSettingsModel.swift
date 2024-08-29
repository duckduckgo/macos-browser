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

        struct CustomBackgroundModeModel: Identifiable, Hashable {
            let contentType: ContentType
            let title: String
            let customBackgroundThumbnail: CustomBackground?

            var id: String {
                title
            }
        }

        let appearancePreferences: AppearancePreferences
        let customImagesManager: UserBackgroundImagesManaging?
        let sendPixel: (PixelKitEvent) -> Void
        let openFilePanel: () -> URL?
        let showAddImageFailedAlert: () -> Void
        let openSettings: () -> Void

        @Published private(set) var availableUserBackgroundImages: [UserBackgroundImage] = []

        private var availableCustomImagesCancellable: AnyCancellable?

        convenience init(openSettings: @escaping () -> Void) {
            self.init(
                appearancePreferences: .shared,
                userBackgroundImagesManager: UserBackgroundImagesManager(
                    maximumNumberOfImages: Const.maximumNumberOfUserImages,
                    applicationSupportDirectory: URL.sandboxApplicationSupportURL
                ),
                sendPixel: { pixelEvent in
                    PixelKit.fire(pixelEvent)
                },
                openFilePanel: {
                    let panel = NSOpenPanel(allowedFileTypes: [.image])
                    guard case .OK = panel.runModal(), let url = panel.url else {
                        return nil
                    }
                    return url
                },
                showAddImageFailedAlert: {
                    let alert = NSAlert.cannotReadImageAlert()
                    alert.runModal()
                },
                openSettings: openSettings
            )
        }

        init(
            appearancePreferences: AppearancePreferences,
            userBackgroundImagesManager: UserBackgroundImagesManaging?,
            sendPixel: @escaping (PixelKitEvent) -> Void,
            openFilePanel: @escaping () -> URL?,
            showAddImageFailedAlert: @escaping () -> Void,
            openSettings: @escaping () -> Void
        ) {
            self.appearancePreferences = appearancePreferences
            self.customImagesManager = userBackgroundImagesManager

            if case .userImage = appearancePreferences.homePageCustomBackground, userBackgroundImagesManager == nil {
                customBackground = nil
            } else {
                customBackground = appearancePreferences.homePageCustomBackground
            }

            self.sendPixel = sendPixel
            self.openFilePanel = openFilePanel
            self.showAddImageFailedAlert = showAddImageFailedAlert
            self.openSettings = openSettings

            availableCustomImagesCancellable = customImagesManager?.availableImagesPublisher
                .receive(on: DispatchQueue.main)
                .handleEvents(receiveOutput: { [weak self] images in
                    guard case .userImage(let userBackgroundImage) = self?.customBackground, !images.contains(userBackgroundImage) else {
                        return
                    }
                    if let firstImage = images.first {
                        self?.customBackground = .userImage(firstImage)
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
            guard let customImagesManager else {
                return false
            }
            return !customImagesManager.availableImages.isEmpty
        }

        func popToRootView() {
            withAnimation {
                contentType = .root
            }
        }

        func handleRootGridSelection(_ modeModel: CustomBackgroundModeModel) {
            if modeModel.contentType == .customImagePicker && !hasUserImages {
                Task {
                    await addNewImage()
                }
            } else {
                withAnimation {
                    contentType = modeModel.contentType
                }
            }
        }

        @Published private(set) var contentType: ContentType = .root {
            didSet {
                if contentType == .root, oldValue == .customImagePicker {
                    customImagesManager?.sortImagesByLastUsed()
                }
            }
        }

        @Published var customBackground: CustomBackground? {
            didSet {
                appearancePreferences.homePageCustomBackground = customBackground
                if case .userImage(let userBackgroundImage) = customBackground {
                    customImagesManager?.updateSelectedTimestamp(for: userBackgroundImage)
                }
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
                case .userImage:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedUserImage)
                case .none:
                    sendPixel(NewTabBackgroundPixel.newTabBackgroundReset)
                }
            }
        }

        @MainActor
        func addNewImage() async {
            guard let customImagesManager, let url = openFilePanel() else {
                return
            }

            do {
                let image = try await customImagesManager.addImage(with: url)
                customBackground = .userImage(image)
                Logger.homePageSettings.debug("New user image added")
            } catch {
                sendPixel(DebugEvent(NewTabBackgroundPixel.newTabBackgroundAddImageError, error: error))
                showAddImageFailedAlert()
                Logger.homePageSettings.error("Failed to add user image: \(error)")
            }
        }

        var customBackgroundModes: [CustomBackgroundModeModel] {
            [
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .colorPicker),
                customBackgroundModeModel(for: .illustrationPicker),
                customBackgroundModeModel(for: .customImagePicker)
            ]
                .compactMap { $0 }
        }

        private func customBackgroundModeModel(for contentType: ContentType) -> CustomBackgroundModeModel? {
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
            case .customImagePicker:
                guard let customImagesManager else {
                    return nil
                }
                let title = customImagesManager.availableImages.isEmpty ? UserText.addBackground : UserText.myBackgrounds
                let thumbnail: CustomBackground? = {
                    guard customBackground?.userBackgroundImage == nil else {
                        return customBackground
                    }
                    guard let lastUsedUserBackgroundImage = customImagesManager.availableImages.first else {
                        return nil
                    }
                    return .userImage(lastUsedUserBackgroundImage)
                }()
                return CustomBackgroundModeModel(contentType: .customImagePicker, title: title, customBackgroundThumbnail: thumbnail)
            }
        }
    }
}
