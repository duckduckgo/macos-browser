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
    private var userScript: NewTabPageUserScript!

    override func setUpWithError() throws {
        try super.setUpWithError()
        model = CapturingNewTabPageCustomBackgroundProvider()
        client = NewTabPageCustomBackgroundClient(model: model)

        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - deleteImage

    func testThatDeleteImageCallsModel() async throws {
        let deleteData = NewTabPageDataModel.DeleteImageData(id: "abcd")
        try await handleMessageExpectingNilResponse(named: .deleteImage, parameters: deleteData)
        XCTAssertEqual(model.deleteImageCalls, ["abcd"])
    }

    // MARK: - setBackground

    func testThatSetBackgroundCallsModel() async throws {
        let backgroundData = NewTabPageDataModel.BackgroundData(background: .gradient("gradient01"))
        try await handleMessageExpectingNilResponse(named: .setBackground, parameters: backgroundData)
        XCTAssertEqual(model.background, .gradient("gradient01"))
    }

    // MARK: - setTheme

    func testThatSetThemeCallsModel() async throws {
        let themeData = NewTabPageDataModel.ThemeData(theme: .dark)
        try await handleMessageExpectingNilResponse(named: .setTheme, parameters: themeData)
        XCTAssertEqual(model.theme, .dark)
    }

    // MARK: - upload

    func testThatUploadCallsModel() async throws {
        try await handleMessageExpectingNilResponse(named: .upload)
        XCTAssertEqual(model.presentUploadDialogCallsCount, 1)
    }

    // MARK: - Helper functions

    func handleMessage<Response: Encodable>(named methodName: NewTabPageCustomBackgroundClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func handleMessageIgnoringResponse(named methodName: NewTabPageCustomBackgroundClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
    }

    func handleMessageExpectingNilResponse(named methodName: NewTabPageCustomBackgroundClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
