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
import Foundation
import PixelKit
@testable import DuckDuckGo_Privacy_Browser
import XCTest

private typealias SettingsModel = HomePage.Models.SettingsModel

final class MockUserBackgroundImagesManager: UserBackgroundImagesManaging {

    init(storageLocation: URL, maximumNumberOfImages: Int = HomePage.Models.SettingsModel.Const.maximumNumberOfUserImages) {
        self.storageLocation = storageLocation
        self.maximumNumberOfImages = maximumNumberOfImages
    }

    let storageLocation: URL
    let maximumNumberOfImages: Int

    @Published var availableImages: [UserBackgroundImage] = []

    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> {
        $availableImages.removeDuplicates().eraseToAnyPublisher()
    }

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        nil
    }

    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        nil
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage {
        .init(fileName: "abc", colorScheme: .light)
    }

    func deleteImage(_ userBackgroundImage: UserBackgroundImage) {
    }

    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage) {
    }

    func sortImagesByLastUsed() {
    }
}

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
    var appearancePreferencesPersistor: AppearancePreferencesPersistorMock!
    var userBackgroundImagesManager: MockUserBackgroundImagesManager!
    var openSettingsCallCount = 0
    var sendPixelCalls: [PixelKitEvent] = []
    var openFilePanelCallCount = 0
    var imageURL: URL?

    override func setUp() async throws {
        openSettingsCallCount = 0
        sendPixelCalls = []

        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        appearancePreferencesPersistor = AppearancePreferencesPersistorMock()
        userBackgroundImagesManager = MockUserBackgroundImagesManager(storageLocation: storageLocation, maximumNumberOfImages: 4)
        model = SettingsModel(
            appearancePreferences: .init(persistor: appearancePreferencesPersistor),
            userBackgroundImagesManager: userBackgroundImagesManager,
            sendPixel: { [weak self] in self?.sendPixelCalls.append($0) },
            openFilePanel: { [weak self] in
                self?.openFilePanelCallCount += 1
                return self?.imageURL
            },
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
        model.handleRootGridSelection(.customImagePicker)
        XCTAssertEqual(model.contentType, .root)
        XCTAssertEqual(openFilePanelCallCount, 1)
    }

    func testWhenThereAreUserImagesThenHandleRootGridSelectionOpensUserImages() {
        userBackgroundImagesManager.availableImages = [.init(fileName: "abc", colorScheme: .light)]
        model.handleRootGridSelection(.customImagePicker)
        XCTAssertEqual(model.contentType, .customImagePicker)
        XCTAssertEqual(openFilePanelCallCount, 0)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storageLocation)
    }
}
