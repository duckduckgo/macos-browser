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
import NewTabPage
import os.log
import PixelKit
import SwiftUI
import SwiftUIExtensions

protocol SettingsVisibilityModelPersistor {
    var didShowSettingsOnboarding: Bool { get set }
}

final class UserDefaultsSettingsVisibilityModelPersistor: SettingsVisibilityModelPersistor {
    @UserDefaultsWrapper(key: .homePageDidShowSettingsOnboarding, defaultValue: false)
    var didShowSettingsOnboarding: Bool
}

extension HomePage.Models {
    /**
     * This tiny model is used by HomePageViewController to expose a setting to control settings visibility,
     * as well as to keep track of the settings onboarding popover.
     */
    final class SettingsVisibilityModel: ObservableObject {
        @Published var isSettingsVisible: Bool = false

        var didShowSettingsOnboarding: Bool {
            get {
                persistor.didShowSettingsOnboarding
            }
            set {
                persistor.didShowSettingsOnboarding = newValue
            }
        }

        init(persistor: SettingsVisibilityModelPersistor = UserDefaultsSettingsVisibilityModelPersistor()) {
            self.persistor = persistor
        }

        private var persistor: SettingsVisibilityModelPersistor
    }

    final class SettingsModel: ObservableObject {

        enum Const {
            static let maximumNumberOfUserImages = 8
            static let defaultColorPickerColor = NSColor.white
        }

        enum ContentType: Equatable {
            case root
            case gradientPicker
            case colorPicker
            case customImagePicker
            case defaultBackground
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
        let userColorProvider: () -> UserColorProviding
        let showAddImageFailedAlert: () -> Void
        let navigator: HomePageSettingsModelNavigator
        let customizerOpener = NewTabPageCustomizerOpener()

        @Published var settingsButtonWidth: CGFloat = .infinity
        @Published private(set) var availableUserBackgroundImages: [UserBackgroundImage] = []

        private var availableCustomImagesCancellable: AnyCancellable?
        private var userColorCancellable: AnyCancellable?
        private var customBackgroundPixelCancellable: AnyCancellable?

        convenience init() {
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
                userColorProvider: NSColorPanel.shared,
                showAddImageFailedAlert: {
                    let alert = NSAlert.cannotReadImageAlert()
                    alert.runModal()
                },
                navigator: DefaultHomePageSettingsModelNavigator()
            )
        }

        init(
            appearancePreferences: AppearancePreferences,
            userBackgroundImagesManager: UserBackgroundImagesManaging?,
            sendPixel: @escaping (PixelKitEvent) -> Void,
            openFilePanel: @escaping () -> URL?,
            userColorProvider: @autoclosure @escaping () -> UserColorProviding,
            showAddImageFailedAlert: @escaping () -> Void,
            navigator: HomePageSettingsModelNavigator
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
            self.userColorProvider = userColorProvider
            self.showAddImageFailedAlert = showAddImageFailedAlert
            self.navigator = navigator

            subscribeToUserBackgroundImages()
            subscribeToCustomBackground()

            if let lastPickedCustomColorHexValue, let customColor = NSColor(hex: lastPickedCustomColorHexValue) {
                lastPickedCustomColor = customColor
            }
            updateSolidColorPickerItems(pickerColor: lastPickedCustomColor ?? Const.defaultColorPickerColor)
        }

        private func subscribeToUserBackgroundImages() {
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

        private func subscribeToCustomBackground() {
            let customBackgroundPublisher: AnyPublisher<CustomBackground?, Never> = {
                if NSApp.runType == .unitTests {
                    return $customBackground.dropFirst().eraseToAnyPublisher()
                }
                return $customBackground.dropFirst()
                    .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
                    .eraseToAnyPublisher()
            }()

            customBackgroundPixelCancellable = customBackgroundPublisher
                .sink { [weak self] customBackground in
                    switch customBackground {
                    case .gradient:
                        self?.sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedGradient)
                    case .solidColor:
                        self?.sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor)
                    case .userImage:
                        self?.sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedUserImage)
                    case .none:
                        self?.sendPixel(NewTabBackgroundPixel.newTabBackgroundReset)
                    }
                }
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
            } else if modeModel.contentType == .defaultBackground {
                withAnimation {
                    customBackground = nil
                }
            } else {
                withAnimation {
                    contentType = modeModel.contentType
                }
            }
        }

        func openSettings() {
            navigator.openAppearanceSettings()
        }

        @Published private(set) var contentType: ContentType = .root {
            didSet {
                assert(contentType != .defaultBackground, "contentType can't be set to .defaultBackground")
                if contentType == .root, oldValue == .customImagePicker {
                    customImagesManager?.sortImagesByLastUsed()
                }
            }
        }

        @Published var customBackground: CustomBackground? {
            didSet {
                appearancePreferences.homePageCustomBackground = customBackground
                switch customBackground {
                case .solidColor(let solidColorBackground) where solidColorBackground.predefinedColorName == nil:
                    lastPickedCustomColor = solidColorBackground.color
                case .userImage(let userBackgroundImage):
                    customImagesManager?.updateSelectedTimestamp(for: userBackgroundImage)
                default:
                    break
                }
                if let customBackground {
                    Logger.homePageSettings.debug("Home page background updated: \(customBackground), color scheme: \(customBackground.colorScheme)")
                } else {
                    Logger.homePageSettings.debug("Home page background reset")
                }
            }
        }

        private(set) var solidColorPickerItems: [SolidColorBackgroundPickerItem] = []

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

        @Published private(set) var lastPickedCustomColor: NSColor? {
            didSet {
                guard let lastPickedCustomColor else {
                    return
                }
                lastPickedCustomColorHexValue = lastPickedCustomColor.hex()
                updateSolidColorPickerItems(pickerColor: lastPickedCustomColor)
            }
        }

        private func updateSolidColorPickerItems(pickerColor: NSColor = Const.defaultColorPickerColor) {
            let predefinedColorBackgrounds = SolidColorBackground.predefinedColors.map(SolidColorBackgroundPickerItem.background)
            solidColorPickerItems = [.picker(.init(color: pickerColor))] + predefinedColorBackgrounds
        }

        @UserDefaultsWrapper(key: .homePageLastPickedCustomColor, defaultValue: nil)
        private var lastPickedCustomColorHexValue: String?

        func openColorPanel() {
            userColorCancellable?.cancel()
            let provider = userColorProvider()
            provider.showColorPanel(with: lastPickedCustomColorHexValue.flatMap(NSColor.init(hex:)) ?? Const.defaultColorPickerColor)

            userColorCancellable = provider.colorPublisher
                .map { CustomBackground.solidColor(.init(color: $0)) }
                .assign(to: \.customBackground, onWeaklyHeld: self)
        }

        func onColorPickerDisappear() {
            userColorCancellable?.cancel()
            userColorProvider().closeColorPanel()
        }

        var customBackgroundModes: [CustomBackgroundModeModel] {
            [
                customBackgroundModeModel(for: .defaultBackground),
                customBackgroundModeModel(for: .colorPicker),
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .customImagePicker)
            ]
                .compactMap { $0 }
        }

        /**
         * This function is used from Debug Menu and shouldn't otherwise be used in the code accessible to the users.
         */
        func resetAllCustomizations() {
            customBackground = nil
            lastPickedCustomColor = nil
            lastPickedCustomColorHexValue = nil
            customImagesManager?.availableImages.forEach { image in
                customImagesManager?.deleteImage(image)
            }
            updateSolidColorPickerItems()
            onColorPickerDisappear()
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
            case .defaultBackground:
                return CustomBackgroundModeModel(contentType: .defaultBackground, title: UserText.defaultBackground, customBackgroundThumbnail: nil)
            }
        }
    }
}
