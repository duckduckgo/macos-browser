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

protocol UserColorProviding {
    var colorPublisher: AnyPublisher<NSColor, Never> { get }

    func showColorPanel(with color: NSColor?)
    func closeColorPanel()
}

extension NSColorPanel: UserColorProviding {
    var colorPublisher: AnyPublisher<NSColor, Never> {
        publisher(for: \.color).removeDuplicates().eraseToAnyPublisher()
    }

    func showColorPanel(with color: NSColor?) {
        if let color {
            self.color = color
        }

        if !isVisible {
            var frame = self.frame
            frame.origin = NSEvent.mouseLocation
            if let keyWindow = NSApp.keyWindow {
                frame.origin.x = keyWindow.frame.maxX - frame.size.width
            }
            frame.origin.y -= frame.size.height + 40
            setFrame(frame, display: true)
        }

        showsAlpha = false
        orderFront(nil)
    }

    func closeColorPanel() {
        close()
    }
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
        let userColorProvider: () -> UserColorProviding
        let showAddImageFailedAlert: () -> Void
        let openSettings: () -> Void

        @Published private(set) var availableUserBackgroundImages: [UserBackgroundImage] = []

        private var availableCustomImagesCancellable: AnyCancellable?
        private var userColorCancellable: AnyCancellable?
        private var customBackgroundPixelCancellable: AnyCancellable?

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
                userColorProvider: NSColorPanel.shared,
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
            userColorProvider: @autoclosure @escaping () -> UserColorProviding,
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
            self.userColorProvider = userColorProvider
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

            let customBackgroundPublisher: AnyPublisher<CustomBackground?, Never> = {
                if NSApp.runType == .unitTests {
                    return $customBackground.dropFirst().eraseToAnyPublisher()
                }
                return $customBackground.dropFirst()
                    .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
                    .eraseToAnyPublisher()
            }()

            customBackgroundPixelCancellable = customBackgroundPublisher
                .sink { customBackground in
                    switch customBackground {
                    case .gradient:
                        sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedGradient)
                    case .solidColor:
                        sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor)
                    case .userImage:
                        sendPixel(NewTabBackgroundPixel.newTabBackgroundSelectedUserImage)
                    case .none:
                        sendPixel(NewTabBackgroundPixel.newTabBackgroundReset)
                    }
                }

            if let customColor = NSColor(hex: lastPickedCustomColorHexValue) {
                lastPickedCustomColor = customColor
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

        @Published private(set) var lastPickedCustomColor: NSColor = .white {
            didSet {
                lastPickedCustomColorHexValue = lastPickedCustomColor.hex()
                let predefinedColorBackgrounds = SolidColorBackground.predefinedColors.map(SolidColorBackgroundPickerItem.background)
                solidColorPickerItems = [.picker(.init(color: lastPickedCustomColor))] + predefinedColorBackgrounds
            }
        }

        @UserDefaultsWrapper(key: .homePageLastPickedCustomColor, defaultValue: "#FFFFFF")
        private var lastPickedCustomColorHexValue: String

        func openColorPanel() {
            let provider = userColorProvider()
            provider.showColorPanel(with: NSColor(hex: lastPickedCustomColorHexValue))

            userColorCancellable = provider.colorPublisher
                .handleEvents(receiveOutput: { [weak self] color in
                    self?.lastPickedCustomColor = color
                })
                .map { CustomBackground.solidColor(.init(color: $0)) }
                .assign(to: \.customBackground, onWeaklyHeld: self)
        }

        func onColorPickerDisappear() {
            userColorCancellable?.cancel()
            userColorProvider().closeColorPanel()
        }

        var customBackgroundModes: [CustomBackgroundModeModel] {
            [
                customBackgroundModeModel(for: .gradientPicker),
                customBackgroundModeModel(for: .colorPicker),
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
