//
//  NewTabPageCustomBackgroundClientTests.swift
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

import AppKit
import Combine
import XCTest
@testable import NewTabPage

final class NewTabPageCustomBackgroundClientTests: XCTestCase {
    private var client: NewTabPageCustomBackgroundClient!
    private var model: CapturingNewTabPageCustomBackgroundProvider!
    private var contextMenuPresenter: CapturingNewTabPageContextMenuPresenter!
    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageCustomBackgroundClient.MessageName>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        model = CapturingNewTabPageCustomBackgroundProvider()
        contextMenuPresenter = CapturingNewTabPageContextMenuPresenter()
        client = NewTabPageCustomBackgroundClient(model: model, contextMenuPresenter: contextMenuPresenter)

        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - contextMenu

    func testThatContextMenuActionIsForwardedToTheModel() async throws {
        let action = NewTabPageDataModel.UserImageContextMenu(target: .userImage, id: "abcd.jpg")
        try await messageHelper.handleMessageExpectingNilResponse(named: .contextMenu, parameters: action)
        XCTAssertEqual(model.showContextMenuCalls, ["abcd.jpg"])
    }

    // MARK: - deleteImage

    func testThatDeleteImageCallsModel() async throws {
        let deleteData = NewTabPageDataModel.DeleteImageData(id: "abcd")
        try await messageHelper.handleMessageExpectingNilResponse(named: .deleteImage, parameters: deleteData)
        XCTAssertEqual(model.deleteImageCalls, ["abcd"])
    }

    // MARK: - setBackground

    func testThatSetBackgroundCallsModel() async throws {
        let backgroundData = NewTabPageDataModel.BackgroundData(background: .gradient("gradient01"))
        try await messageHelper.handleMessageExpectingNilResponse(named: .setBackground, parameters: backgroundData)
        XCTAssertEqual(model.background, .gradient("gradient01"))
    }

    // MARK: - setTheme

    func testThatSetThemeCallsModel() async throws {
        let themeData = NewTabPageDataModel.ThemeData(theme: .dark)
        try await messageHelper.handleMessageExpectingNilResponse(named: .setTheme, parameters: themeData)
        XCTAssertEqual(model.theme, .dark)
    }

    // MARK: - upload

    func testThatUploadCallsModel() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .upload)
        XCTAssertEqual(model.presentUploadDialogCallsCount, 1)
    }
}
