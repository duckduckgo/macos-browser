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
    static let illustrationPicker: Self = .init(contentType: .illustrationPicker, title: "", customBackgroundThumbnail: nil)
    static let customImagePicker: Self = .init(contentType: .customImagePicker, title: "", customBackgroundThumbnail: nil)
}

final class HomePageSettingsModelTests: XCTestCase {

    fileprivate var model: SettingsModel!
    var storageLocation: URL!
    var appearancePreferences: AppearancePreferences!
    var userBackgroundImagesManager: CapturingUserBackgroundImagesManager!
    var navigator: MockHomePageSettingsModelNavigator!
    var sendPixelEvents: [PixelKitEvent] = []
    var openFilePanel: () -> URL? = { return "file:///sample.jpg".url! }
    var openFilePanelCallCount = 0
    var showImageFailedAlertCallCount = 0
    var imageURL: URL?

    override func setUp() async throws {
        navigator = MockHomePageSettingsModelNavigator()
        sendPixelEvents = []

        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        appearancePreferences = .init(persistor: AppearancePreferencesPersistorMock())
        userBackgroundImagesManager = CapturingUserBackgroundImagesManager(storageLocation: storageLocation, maximumNumberOfImages: 4)
        model = SettingsModel(
            appearancePreferences: appearancePreferences,
            userBackgroundImagesManager: userBackgroundImagesManager,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) },
            openFilePanel: { [weak self] in
                self?.openFilePanelCallCount += 1
                return self?.openFilePanel()
            },
            showAddImageFailedAlert: { [weak self] in self?.showImageFailedAlertCallCount += 1 },
            navigator: navigator
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

    func testThatHandleRootGridSelectionUpdatesContentType() {
        model.handleRootGridSelection(.colorPicker)
        XCTAssertEqual(model.contentType, .colorPicker)

        model.handleRootGridSelection(.gradientPicker)
        XCTAssertEqual(model.contentType, .gradientPicker)

        model.handleRootGridSelection(.illustrationPicker)
        XCTAssertEqual(model.contentType, .illustrationPicker)
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
        model.customBackground = .solidColor(.black)
        model.customBackground = .gradient(.gradient01)
        model.customBackground = .illustration(.illustration01)
        model.customBackground = .userImage(.init(fileName: "abc", colorScheme: .light))
        model.customBackground = nil

        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedGradient.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedIllustration.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedUserImage.name,
            NewTabBackgroundPixel.newTabBackgroundReset.name
        ])
    }

    func testThatCustomBackgroundIsPersistedToAppearancePreferences() {
        model.customBackground = .solidColor(.black)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.solidColor(.black))
        model.customBackground = .gradient(.gradient01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.gradient(.gradient01))
        model.customBackground = .illustration(.illustration01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, CustomBackground.illustration(.illustration01))
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
            .gradient(CustomBackground.placeholderGradient),
            .solidColor(CustomBackground.placeholderColor),
            .illustration(CustomBackground.placeholderIllustration),
            nil
        ])

        model.customBackground = .gradient(.gradient04)
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            .gradient(.gradient04),
            .solidColor(CustomBackground.placeholderColor),
            .illustration(CustomBackground.placeholderIllustration),
            nil
        ])

        model.customBackground = .solidColor(.darkPink)
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            .gradient(CustomBackground.placeholderGradient),
            .solidColor(.darkPink),
            .illustration(CustomBackground.placeholderIllustration),
            nil
        ])

        model.customBackground = .illustration(.illustration02)
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            .gradient(CustomBackground.placeholderGradient),
            .solidColor(CustomBackground.placeholderColor),
            .illustration(.illustration02),
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
            .gradient(CustomBackground.placeholderGradient),
            .solidColor(CustomBackground.placeholderColor),
            .illustration(CustomBackground.placeholderIllustration),
            .userImage(image1)
        ])

        userBackgroundImagesManager.availableImages = [image2, image1, image3]
        XCTAssertEqual(model.customBackgroundModes.map(\.customBackgroundThumbnail), [
            .gradient(CustomBackground.placeholderGradient),
            .solidColor(CustomBackground.placeholderColor),
            .illustration(CustomBackground.placeholderIllustration),
            .userImage(image2)
        ])
    }
}
