//
//  SettingsModelTests.swift
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
    static let root: Self = .init(contentType: .root, title: "", customBackgroundPreview: nil)
    static let gradientPicker: Self = .init(contentType: .gradientPicker, title: "", customBackgroundPreview: nil)
    static let colorPicker: Self = .init(contentType: .colorPicker, title: "", customBackgroundPreview: nil)
    static let illustrationPicker: Self = .init(contentType: .illustrationPicker, title: "", customBackgroundPreview: nil)
    static let customImagePicker: Self = .init(contentType: .customImagePicker, title: "", customBackgroundPreview: nil)
}

final class SettingsModelTests: XCTestCase {

    fileprivate var model: SettingsModel!
    var storageLocation: URL!
    var appearancePreferences: AppearancePreferences!
    var userBackgroundImagesManager: CapturingUserBackgroundImagesManager!
    var openSettingsCallCount = 0
    var sendPixelEvents: [PixelKitEvent] = []
    var openFilePanel: () -> URL? = { return "file:///sample.jpg".url! }
    var openFilePanelCallCount = 0
    var showImageFailedAlertCallCount = 0
    var imageURL: URL?

    override func setUp() async throws {
        openSettingsCallCount = 0
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
            openSettings: { [weak self] in self?.openSettingsCallCount += 1 }
        )
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
        model.customBackground = .customImage(.init(fileName: "abc", colorScheme: .light))
        model.customBackground = nil

        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabPagePixel.newTabBackgroundSelectedSolidColor.name,
            NewTabPagePixel.newTabBackgroundSelectedGradient.name,
            NewTabPagePixel.newTabBackgroundSelectedIllustration.name,
            NewTabPagePixel.newTabBackgroundSelectedUserImage.name,
            NewTabPagePixel.newTabBackgroundReset.name
        ])
    }

    func testThatCustomBackgroundIsPersistedToAppearancePreferences() {
        model.customBackground = .solidColor(.black)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, SettingsModel.CustomBackground.solidColor(.black))
        model.customBackground = .gradient(.gradient01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, SettingsModel.CustomBackground.gradient(.gradient01))
        model.customBackground = .illustration(.illustration01)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, SettingsModel.CustomBackground.illustration(.illustration01))
        let userImage = UserBackgroundImage(fileName: "abc", colorScheme: .light)
        model.customBackground = .customImage(userImage)
        XCTAssertEqual(appearancePreferences.homePageCustomBackground, SettingsModel.CustomBackground.customImage(userImage))
        model.customBackground = nil
        XCTAssertNil(appearancePreferences.homePageCustomBackground)
    }

    func testWhenUserImageIsSelectedThenItsTimestampIsUpdated() {
        let userImage = UserBackgroundImage(fileName: "abc", colorScheme: .light)
        var updateSelectedTimestampForUserBackgroundImageArguments: [UserBackgroundImage] = []

        userBackgroundImagesManager.updateSelectedTimestampForUserBackgroundImage = { image in
            updateSelectedTimestampForUserBackgroundImageArguments.append(image)
        }
        model.customBackground = .customImage(userImage)

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
        openFilePanel = { "file:///sample.jpg".url! }
        await model.addNewImage()
        XCTAssertEqual(userBackgroundImagesManager.addImageWithURLCallCount, 1)
        XCTAssertEqual(model.customBackground, .customImage(.init(fileName: "sample.jpg", colorScheme: .light)))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabPagePixel.newTabBackgroundSelectedUserImage.name
        ])
        XCTAssertEqual(showImageFailedAlertCallCount, 0)
    }

    func testAddImageWhenImageAddingFailsThenAlertIsShown() async {
        struct TestError: Error {}
        openFilePanel = { "file:///sample.jpg".url! }
        userBackgroundImagesManager.addImageWithURL = { _ in
            throw TestError()
        }

        let originalCustomBackground = model.customBackground
        await model.addNewImage()

        XCTAssertEqual(userBackgroundImagesManager.addImageWithURLCallCount, 1)
        XCTAssertEqual(model.customBackground, originalCustomBackground)
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabPagePixel.newTabBackgroundAddImageError.name
        ])
        XCTAssertEqual(showImageFailedAlertCallCount, 1)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storageLocation)
    }
}
