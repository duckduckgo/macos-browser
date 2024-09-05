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
}

final class HomePageSettingsModelTests: XCTestCase {

    fileprivate var model: SettingsModel!
    var storageLocation: URL!
    var appearancePreferences: AppearancePreferences!
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
        model = SettingsModel(
            appearancePreferences: appearancePreferences,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) },
            openSettings: { [weak self] in self?.openSettingsCallCount += 1 }
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

    func testWhenCustomBackgroundIsUpdatedThenPixelIsSent() {
        model.customBackground = .solidColor(.black)
        model.customBackground = .gradient(.gradient01)
        model.customBackground = .illustration(.illustration01)
        model.customBackground = nil

        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundSelectedSolidColor.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedGradient.name,
            NewTabBackgroundPixel.newTabBackgroundSelectedIllustration.name,
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
        model.customBackground = nil
        XCTAssertNil(appearancePreferences.homePageCustomBackground)
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
}
