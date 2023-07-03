//
//  YoutubeOverlayUserScriptTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit
import UserScript

final class YoutubeOverlayUserScriptTests: XCTestCase {

    var youtubeOverlayUserScript: YoutubeOverlayUserScript!
    var preferences: DuckPlayerPreferences!
    var persistor: DuckPlayerPreferencesPersistorMock!

    override func setUp() {
        persistor = DuckPlayerPreferencesPersistorMock()
        preferences = DuckPlayerPreferences(persistor: persistor)
        youtubeOverlayUserScript = YoutubeOverlayUserScript(duckPlayerPreferences: preferences)
    }

    override func tearDown() {
        persistor = nil
        preferences = nil
        youtubeOverlayUserScript = nil
    }

    @MainActor func testWhenHandleSendJSPixelWithForPlayUsePixelYoutubeOverlayUserPressedButtonsSetTrue() {
        let message = MockMessage(messageBody: ["params": ["pixelName": "play.use"]])
        _ = youtubeOverlayUserScript.handleSendJSPixel(params: ["something"], message: message)

        XCTAssertTrue(persistor.youtubeOverlayAnyButtonPressed)
    }

    @MainActor func testWhenHandleSendJSPixelWithForPlayDoNotUsePixelYoutubeOverlayUserPressedButtonsSetTrue() {
        let message = MockMessage(messageBody: ["params": ["pixelName": "play.do_not_use"]])
        _ = youtubeOverlayUserScript.handleSendJSPixel(params: ["something"], message: message)

        XCTAssertTrue(persistor.youtubeOverlayAnyButtonPressed)
    }

    @MainActor func testWhenHandleSendJSPixelWithForPlayOverlayPixelYoutubeOverlayUserPressedButtonsNotSet() {
        let message = MockMessage(messageBody: ["params": ["pixelName": "overlay"]])
        _ = youtubeOverlayUserScript.handleSendJSPixel(params: ["something"], message: message)

        XCTAssertFalse(persistor.youtubeOverlayAnyButtonPressed)
    }

}

struct MockMessage: UserScriptMessage {
    var messageName: String = ""
    var messageBody: Any
    var messageHost: String = ""
    var isMainFrame: Bool = false
    var messageWebView: WKWebView?
}
