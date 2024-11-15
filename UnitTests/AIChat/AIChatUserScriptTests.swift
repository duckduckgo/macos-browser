//
//  AIChatUserScriptTests.swift
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

import XCTest
import UserScript

@testable import DuckDuckGo_Privacy_Browser

final class AIChatUserScriptTests: XCTestCase {
    var mockHandler: MockAIChatUserScriptHandler!
    var userScript: AIChatUserScript!

    override func setUp() {
        super.setUp()
        mockHandler = MockAIChatUserScriptHandler()
        userScript = AIChatUserScript(handler: mockHandler, urlSettings: AIChatMockDebugSettings())
    }

    override func tearDown() {
        mockHandler = nil
        userScript = nil
        super.tearDown()
    }

    @MainActor func testOpenSettingsMessageTriggersOpenSettingsMethod() async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: AIChatUserScript.MessageNames.openSettings.rawValue))
        _ = try await handler([""], WKScriptMessage())

        XCTAssertTrue(mockHandler.didOpenSettings, "openSettings should be called")
    }

    @MainActor func testGetUserValuesMessageReturnsCorrectUserValues() async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: AIChatUserScript.MessageNames.getUserValues.rawValue))

        let result = try await handler([""], WKScriptMessage())

        if let userValues = result as? AIChatUserScriptHandler.UserValues {
            XCTAssertTrue(userValues.isToolbarShortcutEnabled, "isToolbarShortcutEnabled should be true")
            XCTAssertEqual(userValues.platform, "macOS", "Platform should be macOS")
        } else {
            XCTFail("Expected result to be of type UserValues")
        }
    }
}

final class MockAIChatUserScriptHandler: AIChatUserScriptHandling {
    var didOpenSettings = false

    func openSettings(params: Any, message: UserScriptMessage) -> Encodable? {
        didOpenSettings = true
        return nil
    }

    func handleGetUserValues(params: Any, message: UserScriptMessage) -> Encodable? {
        return AIChatUserScriptHandler.UserValues(isToolbarShortcutEnabled: true, platform: "macOS")
    }
}

private final class AIChatMockDebugSettings: AIChatDebugURLSettingsRepresentable {
    var customURLHostname: String?
    var customURL: String?
    func reset() { }
}
