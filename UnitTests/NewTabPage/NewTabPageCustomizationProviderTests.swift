//
//  NewTabPageCustomizationProviderTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import AppKitExtensions
import NewTabPage
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NewTabPageCustomizationProviderTests: XCTestCase {
    var storageLocation: URL!
    var appearancePreferences: AppearancePreferences!
    var userColorProvider: MockUserColorProvider!
    var userBackgroundImagesManager: CapturingUserBackgroundImagesManager!
    private var settingsModel: HomePage.Models.SettingsModel!
    private var provider: NewTabPageCustomizationProvider!

    @MainActor
    override func setUp() async throws {

        appearancePreferences = AppearancePreferences(persistor: MockAppearancePreferencesPersistor())
        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        userBackgroundImagesManager = CapturingUserBackgroundImagesManager(storageLocation: storageLocation, maximumNumberOfImages: 4)
        userColorProvider = MockUserColorProvider()

        settingsModel = HomePage.Models.SettingsModel(
            appearancePreferences: appearancePreferences,
            userBackgroundImagesManager: userBackgroundImagesManager,
            sendPixel: { _ in },
            openFilePanel: { nil },
            userColorProvider: self.userColorProvider,
            showAddImageFailedAlert: {},
            navigator: MockHomePageSettingsModelNavigator()
        )

        provider = NewTabPageCustomizationProvider(homePageSettingsModel: settingsModel, appearancePreferences: appearancePreferences)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storageLocation)
    }

    func testThatCustomizerOpenerReturnsSettingsModelCustomizerOpener() {
        XCTAssertIdentical(provider.customizerOpener, settingsModel.customizerOpener)
    }

    func testThatBackgroundGetterReturnsSettingsModelBackground() throws {
        settingsModel.customBackground = .gradient(.gradient01)
        XCTAssertEqual(provider.background, .gradient("gradient01"))

        settingsModel.customBackground = .solidColor(.color02)
        XCTAssertEqual(provider.background, .solidColor("color02"))

        let hexColor = try XCTUnwrap(SolidColorBackground("#abcdef"))
        settingsModel.customBackground = .solidColor(hexColor)
        XCTAssertEqual(provider.background, .hexColor("#abcdef"))

        let userImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        settingsModel.customBackground = .userImage(userImage)
        XCTAssertEqual(provider.background, .userImage(.init(userImage)))

        settingsModel.customBackground = nil
        XCTAssertEqual(provider.background, .default)
    }

    func testThatBackgroundSetterSetsCorrectBackgroundInSettingsModel() throws {
        provider.background = .gradient("gradient02.01")
        XCTAssertEqual(settingsModel.customBackground, .gradient(.gradient0201))

        provider.background = .solidColor("color02")
        XCTAssertEqual(settingsModel.customBackground, .solidColor(.color02))

        provider.background = .hexColor("#ABCDEF")
        let hexColor = try XCTUnwrap(SolidColorBackground("#abcdef"))
        XCTAssertEqual(settingsModel.customBackground, .solidColor(hexColor))

        let userImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        provider.background = .userImage(.init(userImage))
        XCTAssertEqual(settingsModel.customBackground, .userImage(userImage))

        provider.background = .default
        XCTAssertEqual(settingsModel.customBackground, nil)
    }

    @MainActor
    func testThatCustomizerDataReturnsCorrectDataFromSettingsModelAndApperancePreferences() async throws {
        try await waitForAvailableUserBackgroundImages {
            userBackgroundImagesManager.availableImages = [
                .init(fileName: "1.jpg", colorScheme: .light),
                .init(fileName: "2.jpg", colorScheme: .dark)
            ]
        }

        // this sets lastPickedCustomColor
        settingsModel.customBackground = .solidColor(try XCTUnwrap(.init("#123abc")))
        settingsModel.customBackground = .solidColor(.color05)
        appearancePreferences.currentThemeName = .light

        XCTAssertEqual(
            provider.customizerData,
            .init(
                background: .solidColor("color05"),
                theme: .light,
                userColor: .init(hex: "#123abc"),
                userImages: userBackgroundImagesManager.availableImages.map(NewTabPageDataModel.UserImage.init)
            )
        )
    }

    // MARK: - Helpers

    /**
     * Sets up an expectation, then sets up Combine subscription for `settingsModel.$availableUserBackgroundImages` that fulfills
     * the expectation, then calls the provided `block` and waits for time specified by `duration` before cancelling the subscription.
     */
    private func waitForAvailableUserBackgroundImages(for duration: TimeInterval = 1, _ block: () async -> Void = {}) async throws {
        let expectation = self.expectation(description: "viewModelUpdate")
        let cancellable = settingsModel.$availableUserBackgroundImages.dropFirst().prefix(1).sink { _ in expectation.fulfill() }

        await block()

        await fulfillment(of: [expectation], timeout: duration)
        cancellable.cancel()
    }
}
