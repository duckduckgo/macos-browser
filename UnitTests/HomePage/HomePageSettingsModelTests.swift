//
//  HomePageSettingsModelTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import Foundation
import PixelKit
import SwiftUI
import XCTest

private typealias SettingsModel = HomePage.Models.SettingsModel

fileprivate extension SettingsModel.CustomBackgroundModeModel {
    static let root: Self = .init(contentType: .root, title: "", customBackgroundThumbnail: nil)
    static let gradientPicker: Self = .init(contentType: .gradientPicker, title: "", customBackgroundThumbnail: nil)
    static let colorPicker: Self = .init(contentType: .colorPicker, title: "", customBackgroundThumbnail: nil)
    static let customImagePicker: Self = .init(contentType: .customImagePicker, title: "", customBackgroundThumbnail: nil)
    static let defaultBackground: Self = .init(contentType: .defaultBackground, title: "", customBackgroundThumbnail: nil)
}

final class MockUserColorProvider: UserColorProviding {
    var colorPublisher: AnyPublisher<NSColor, Never> {
        colorSubject.eraseToAnyPublisher()
    }

    func showColorPanel(with color: NSColor?) {
        showColorPanelCallCount += 1
        showColorPanel(color)
    }

    func closeColorPanel() {
        closeColorPanelCallCount += 1
    }

    var colorSubject = PassthroughSubject<NSColor, Never>()
    var showColorPanelCallCount = 0
    var showColorPanel: (NSColor?) -> Void = { _ in }
    var closeColorPanelCallCount = 0
}

final class HomePageSettingsModelTests: XCTestCase {

    fileprivate var model: SettingsModel!
    var storageLocation: URL!
    var appearancePreferences: AppearancePreferences!
    var userBackgroundImagesManager: CapturingUserBackgroundImagesManager!
    var sendPixelEvents: [PixelKitEvent] = []
    var openFilePanel: () -> URL? = { return "file:///sample.jpg".url! }
    var openFilePanelCallCount = 0
    var showImageFailedAlertCallCount = 0
    var imageURL: URL?
    var userColorProvider: MockUserColorProvider!

    override func setUp() async throws {
        sendPixelEvents = []

        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        appearancePreferences = .init(persistor: AppearancePreferencesPersistorMock())
        userBackgroundImagesManager = CapturingUserBackgroundImagesManager(storageLocation: storageLocation, maximumNumberOfImages: 4)
        userColorProvider = MockUserColorProvider()

        UserDefaultsWrapper<Any>.sharedDefaults.removeObject(forKey: UserDefaultsWrapper<Any>.Key.homePageLastPickedCustomColor.rawValue)

        model = SettingsModel(
            appearancePreferences: appearancePreferences,
            userBackgroundImagesManager: userBackgroundImagesManager,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) },
            openFilePanel: { [weak self] in
                self?.openFilePanelCallCount += 1
                return self?.openFilePanel()
            },
            userColorProvider: self.userColorProvider,
            showAddImageFailedAlert: { [weak self] in self?.showImageFailedAlertCallCount += 1 },
            navigator: MockHomePageSettingsModelNavigator()
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storageLocation)
    }

    func testThatContentTypeIsRootByDefault() {
        XCTAssertEqual(model.contentType, .root)
    }

    func testThatCustomBackgroundIsNilByDefault() {
        XCTAssertNil(model.customBackground)
    }

    func testThatHasUserImagesFollowsAvailableImagesArray() {
        XCTAssertFalse(model.hasUserImages)
        userBackgroundImagesManager.availableImages = [.init(fileName: "abc", colorScheme: .light)]
        XCTAssertTrue(model.hasUserImages)
        userBackgroundImagesManager.availableImages = []
        XCTAssertFalse(model.hasUserImages)
    }

    func testThatPopToRootViewUpdatesContentType() {
        model.handleRootGridSelection(.colorPicker)
        XCTAssertNotEqual(model.contentType, .root)

        model.popToRootView()
        XCTAssertEqual(model.contentType, .root)
    }

    func testThatHandleRootGridSelectionForColorsAndGradientsUpdatesContentType() {
        model.handleRootGridSelection(.colorPicker)
        XCTAssertEqual(model.contentType, .colorPicker)

        model.handleRootGridSelection(.gradientPicker)
        XCTAssertEqual(model.contentType, .gradientPicker)
    }

    func testThatHandleRootGridSelectionForResetBackgroundResetsBackground() {
        let contentType = model.contentType
        model.customBackground = .gradient(.gradient04)
        model.handleRootGridSelection(.defaultBackground)
        XCTAssertNil(model.customBackground)
        XCTAssertEqual(model.contentType, contentType)
    }

    func testWhenThereAreNoUserImagesThenHandleRootGridSelectionOpensFilePicker() {
        let openFilePanelExpectation = expectation(description: "openFilePanel")
        openFilePanel = {
            openFilePanelExpectation.fulfill()
            return "file:///sample.jpg".url!
        }
        model.handleRootGridSelection(.customImagePicker)
        XCTAssertEqual(model.contentType, .root)
        waitForExpectations(timeout: 0.1)
    }

    func testWhenThereAreUserImagesThenHandleRootGridSelectionOpensUserImages() {
        userBackgroundImagesManager.availableImages = [.init(fileName: "abc", colorScheme: .light)]
        model.handleRootGridSelection(.customImagePicker)
        XCTAssertEqual(model.contentType, .customImagePicker)
        XCTAssertEqual(openFilePanelCallCount, 0)
    }

    func testWhenNavigatingFromUserImagePickerToRootThenUserImagesAreSorted() {
        userBackgroundImagesManager.availableImages = [.init(fileName: "abc", colorScheme: .light)]
        model.handleRootGridSelection(.customImagePicker)
        XCTAssertEqual(userBackgroundImagesManager.sortImagesByLastUsedCallCount, 0)

        model.popToRootView()
        XCTAssertEqual(userBackgroundImagesManager.sortImagesByLastUsedCallCount, 1)
    }

    func testWhenCustomBackgroundIsUpdatedThenPixelIsSent() {
        model.customBackground = .solidColor(.color01)
        model.customBackground = .gradient(.gradient01)
        model.customBackground = .userImage(.init(fileName: "abc", colorScheme: .light))
        model.customBackground = nil

        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedGradient.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedUserImage.name,
            NewTabBackgroundPixel.newTabBackgroundReset.name
        ])
    }

    func testThatCustomBackgroundIsPersistedToAppearancePreferences() {
        model.customBackground = .solidColor(.color01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.solidColor(.color01))
        model.customBackground = .gradient(.gradient01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.gradient(.gradient01))
        let userImage = UserBackgroundImage(fileName: "abc", colorScheme: .light)
        model.customBackground = .userImage(userImage)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.userImage(userImage))
        model.customBackground = nil
        XCTAssertNil(appearancePreferences.homePageCustomBackground)
    }

    func testWhenUserImageIsSelectedThenItsTimestampIsUpdated() {
        let userImage = UserBackgroundImage(fileName: "abc", colorScheme: .light)
        var updateSelectedTimestampForUserBackgroundImageArguments: [UserBackgroundImage] = []

        userBackgroundImagesManager.updateSelectedTimestampForUserBackgroundImage = { image in
            updateSelectedTimestampForUserBackgroundImageArguments.append(image)
        }
        model.customBackground = .userImage(userImage)

        XCTAssertEqual(userBackgroundImagesManager.updateSelectedTimestampForUserBackgroundImageCallCount, 1)
        XCTAssertEqual(updateSelectedTimestampForUserBackgroundImageArguments, [userImage])
    }

    func testAddImageWhenImageIsNotSelectedThenReturnsEarly() async {
        openFilePanel = { nil }
        await model.addNewImage()
        XCTAssertEqual(userBackgroundImagesManager.addImageWithURLCallCount, 0)
        XCTAssertTrue(sendPixelEvents.isEmpty)
        XCTAssertEqual(showImageFailedAlertCallCount, 0)
    }

    func testAddImageWhenImageIsAddedThenCustomBackgroundIsUpdated() async {
        await model.addNewImage()
        XCTAssertEqual(userBackgroundImagesManager.addImageWithURLCallCount, 1)
        XCTAssertEqual(model.customBackground, .userImage(.init(fileName: "sample.jpg", colorScheme: .light)))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundSelectedUserImage.name
        ])
        XCTAssertEqual(showImageFailedAlertCallCount, 0)
    }

    func testAddImageWhenImageAddingFailsThenAlertIsShown() async {
        struct TestError: Error {}
        userBackgroundImagesManager.addImageWithURL = { _ in
            throw TestError()
        }

        let originalCustomBackground = model.customBackground
        await model.addNewImage()

        XCTAssertEqual(userBackgroundImagesManager.addImageWithURLCallCount, 1)
        XCTAssertEqual(model.customBackground, originalCustomBackground)
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundAddImageError.name
        ])
        XCTAssertEqual(showImageFailedAlertCallCount, 1)
    }

    func testThatCustomBackgroundModeModelShowsPreviewOfCurrentlySelectedBackground() {
        model.customBackground = nil
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            nil,
            .solidColor(CustomBackground.placeholderColor),
            .gradient(CustomBackground.placeholderGradient),
            nil
        ])

        model.customBackground = .gradient(.gradient04)
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            nil,
            .solidColor(CustomBackground.placeholderColor),
            .gradient(.gradient04),
            nil,
        ])

        model.customBackground = .solidColor(.color17)
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            nil,
            .solidColor(.color17),
            .gradient(CustomBackground.placeholderGradient),
            nil
        ])
    }

    func testThatCustomBackgroundModeModelShowsPreviewOfLastSelectedUserImageIfUserImagesArePresent() {
        let image1 = UserBackgroundImage(fileName: "abc1", colorScheme: .light)
        let image2 = UserBackgroundImage(fileName: "abc2", colorScheme: .light)
        let image3 = UserBackgroundImage(fileName: "abc3", colorScheme: .light)

        userBackgroundImagesManager.availableImages = [image1, image2, image3]
        model.customBackground = nil
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            nil,
            .solidColor(CustomBackground.placeholderColor),
            .gradient(CustomBackground.placeholderGradient),
            .userImage(image1)
        ])

        userBackgroundImagesManager.availableImages = [image2, image1, image3]
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            nil,
            .solidColor(CustomBackground.placeholderColor),
            .gradient(CustomBackground.placeholderGradient),
            .userImage(image2)
        ])
    }

    func testWhenDefaultBackgroundIsSelectedThenCustomBackgroundIsRemoved() {
        model.customBackground = .solidColor(.color01)
        model.handleRootGridSelection(.defaultBackground)
        XCTAssertNil(model.customBackground)
    }

    func testThatSolidColorsArePopulatedUponInitialization() {
        XCTAssertEqual(model.solidColorPickerItems.count, SolidColorBackground.predefinedColors.count + 1)
    }

    func testThatColorPickerIsPresentedWithLastPickedColor() {
        var colors = [NSColor?]()
        userColorProvider.showColorPanel = { color in
            colors.append(color)
        }

        let color = NSColor.green
        UserDefaultsWrapper<Any>.sharedDefaults.set(color.hex(), forKey: UserDefaultsWrapper<Any>.Key.homePageLastPickedCustomColor.rawValue)

        model.openColorPanel()
        XCTAssertEqual(userColorProvider.showColorPanelCallCount, 1)
        XCTAssertEqual(colors, [color])
    }

    func testWhenColorsArePickedThenLastPickedCustomColorIsUpdated() {
        model.openColorPanel()

        userColorProvider.colorSubject.send(.green)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        userColorProvider.colorSubject.send(.blue)
        XCTAssertEqual(model.lastPickedCustomColor, .blue)
        userColorProvider.colorSubject.send(.yellow)
        XCTAssertEqual(model.lastPickedCustomColor, .yellow)
        userColorProvider.colorSubject.send(.white)
        XCTAssertEqual(model.lastPickedCustomColor, .white)
        userColorProvider.colorSubject.send(.red)
        XCTAssertEqual(model.lastPickedCustomColor, .red)
    }

    func testWhenColorPanelIsDismissedThenLastPickedCustomColorIsNotUpdated() {
        model.openColorPanel()

        userColorProvider.colorSubject.send(.green)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        model.onColorPickerDisappear()
        userColorProvider.colorSubject.send(.blue)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        userColorProvider.colorSubject.send(.yellow)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        userColorProvider.colorSubject.send(.white)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        userColorProvider.colorSubject.send(.red)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
    }

    func testThatSolidColorPickerFirstItemRepresentsLastPickedCustomColor() {
        model.openColorPanel()

        userColorProvider.colorSubject.send(.green)
        XCTAssertEqual(model.lastPickedCustomColor, .green)
        XCTAssertEqual(model.solidColorPickerItems.first, .picker(.init(color: .green)))

        userColorProvider.colorSubject.send(.orange)
        XCTAssertEqual(model.lastPickedCustomColor, .orange)
        XCTAssertEqual(model.solidColorPickerItems.first, .picker(.init(color: .orange)))
    }

    func testThatColorPanelIsClosedOnDisappear() {
        XCTAssertEqual(userColorProvider.closeColorPanelCallCount, 0)
        model.onColorPickerDisappear()
        XCTAssertEqual(userColorProvider.closeColorPanelCallCount, 1)
    }
}
