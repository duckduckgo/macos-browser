//
//  OnboardingUserScriptTests.swift
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

final class OnboardingUserScriptTests: XCTestCase {
    var script: OnboardingUserScript!
    var mockManager: CapturingOnboardingActionsManager!

    override func setUp() {
        super.setUp()
        mockManager = CapturingOnboardingActionsManager()
        script = OnboardingUserScript(onboardingActionsManager: mockManager)
    }

    @MainActor
    func testSetInit_ReturnsExpectedParameters() async {
        guard let handler = script.handler(forMethodNamed: "init") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertEqual(result as? OnboardingConfiguration, mockManager.configuration)
    }

    @MainActor
    func testDismissToAddressBar_CallsGoToAddressBar() async {
        guard let handler = script.handler(forMethodNamed: "dismissToAddressBar") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.goToAddressBarCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testDismissToSettings_CallsGoToSettings() async {
        guard let handler = script.handler(forMethodNamed: "dismissToSettings") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.goToSettingsCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testRequestDockOptIn_CallsAddToDock() async {
        guard let handler = script.handler(forMethodNamed: "requestDockOptIn") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.addToDockCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testRequestImport_CallsImportData() async {
        guard let handler = script.handler(forMethodNamed: "requestImport") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.importDataCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testRequestSetAsDefault_CallsSetAsDefault() async {
        guard let handler = script.handler(forMethodNamed: "requestSetAsDefault") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.setAsDefaultCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testSetBookmarksBar_CallsSetBookmarkBar() async {
        guard let handler = script.handler(forMethodNamed: "setBookmarksBar") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.setBookmarkBarCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testSetSessionRestore_CallsSetSessionRestore() async {
        guard let handler = script.handler(forMethodNamed: "setSessionRestore") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.setSessionRestoreCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testSetShowHome_CallsSetShowHomeButtonLeft() async {
        guard let handler = script.handler(forMethodNamed: "setShowHomeButton") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.setShowHomeButtonLeftCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testStepCompleted_CallsStepCompleted() async {
        let randomStep = OnboardingSteps.allCases.randomElement()!
        let params = ["id": randomStep.rawValue]
        guard let handler = script.handler(forMethodNamed: "stepCompleted") else {
            XCTFail("Handler method not found")
            return
        }

        let result = try? await handler(params, WKScriptMessage())
        XCTAssertEqual(mockManager.completedStep, randomStep)
        XCTAssertNil(result)
    }

}
