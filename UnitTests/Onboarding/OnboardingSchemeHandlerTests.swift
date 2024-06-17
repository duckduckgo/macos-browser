//
//  OnboardingSchemeHandlerTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import Common
import BrowserServicesKit
import Combine

final class OnboardingSchemeHandlerTests: XCTestCase {

    func testWebViewFromHandlerReturnsResponseAndData() throws {
        // Given
        let onboardingURL = URL(string: "onboarding://?platform=integration")!
        let handler = OnboardingSchemeHandler()
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: onboardingURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertEqual(schemeTask.response?.url, onboardingURL)
        XCTAssertEqual(schemeTask.response?.mimeType, "text/html")
        XCTAssertNotNil(schemeTask.data)
        XCTAssertTrue(schemeTask.didFinishCalled)
        XCTAssertNil(schemeTask.error)
    }

    @MainActor
    func testSetOnboardingSchemeHandler_WhenNoneExists() {
        // Given
        let configuration = WKWebViewConfiguration()
        XCTAssertNil(configuration.urlSchemeHandler(forURLScheme: "onboarding"))

        // When
        configuration.applyStandardConfiguration(contentBlocking: MockContentBlocking(), burnerMode: .regular)

        // Then
        XCTAssertNotNil(configuration.urlSchemeHandler(forURLScheme: "onboarding"))
        XCTAssertTrue(configuration.urlSchemeHandler(forURLScheme: "onboarding") is OnboardingSchemeHandler)
    }

}
