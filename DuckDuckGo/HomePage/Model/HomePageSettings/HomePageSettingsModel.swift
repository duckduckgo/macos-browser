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
        let sendPixel: (PixelKitEvent) -> Void
        let openFilePanel: () -> URL?
        let openSettings: () -> Void

        @Published private(set) var availableUserBackgroundImages: [UserBackgroundImage] = []

        private var availableCustomImagesCancellable: AnyCancellable?

        init(
            appearancePreferences: AppearancePreferences = .shared,
            userBackgroundImagesManager: UserBackgroundImagesManaging = UserBackgroundImagesManager(
                maximumNumberOfImages: Const.maximumNumberOfUserImages,
                applicationSupportDirectory: URL.sandboxApplicationSupportURL
            ),
            sendPixel: ((PixelKitEvent) -> Void)? = nil,
            openFilePanel: (() -> URL?)? = nil,
            openSettings: @escaping () -> Void
        ) {
            self.appearancePreferences = appearancePreferences
            self.customImagesManager = userBackgroundImagesManager
            customBackground = appearancePreferences.homePageCustomBackground
            self.sendPixel = sendPixel ?? { PixelKit.fire($0) }
            self.openFilePanel = openFilePanel ?? {
                let panel = NSOpenPanel(allowedFileTypes: [.image])
                guard case .OK = panel.runModal(), let url = panel.url else {
                    return nil
                }
                return url
            }
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
                switch customBackground {
                case .gradient:
                    sendPixel(NewTabPagePixel.newTabBackgroundSelectedGradient)
                case .solidColor:
                    sendPixel(NewTabPagePixel.newTabBackgroundSelectedSolidColor)
                case .illustration:
                    sendPixel(NewTabPagePixel.newTabBackgroundSelectedIllustration)
                case .customImage:
                    sendPixel(NewTabPagePixel.newTabBackgroundSelectedUserImage)
                case .none:
                    sendPixel(NewTabPagePixel.newTabBackgroundReset)
                }
            }
        }

        @MainActor
        func addNewImage() async {
            guard let url = openFilePanel() else {
                return
            }

            do {
                let image = try await customImagesManager.addImage(with: url)
                customBackground = .customImage(image)
            } catch {
                sendPixel(DebugEvent(NewTabPagePixel.newTabBackgroundAddImageError, error: error))
                await showAddImageFailedAlert()
            }
        }

        @MainActor
        private func showAddImageFailedAlert() async {
            let alert = NSAlert.cannotReadImageAlert()
            await alert.runModal()
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
            [
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .colorPicker),
                customBackgroundModeModel(for: .illustrationPicker),
                customBackgroundModeModel(for: .customImagePicker)
            ]
        }
    }
}
