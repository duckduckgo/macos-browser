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

    override func tearDown() {
        mockManager = nil
        script = nil
        super.tearDown()
    }

    @MainActor
    func testSetInit_ReturnsExpectedParameters() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "init"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertEqual(result as? OnboardingConfiguration, mockManager.configuration)
        XCTAssertTrue(mockManager.onboardingStartedCalled)
    }

    @MainActor
    func testReportPageException_CallsGoToAddressBar() async throws {
        let params = ["sabrina": "awesome"]
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "reportPageException"))

        let result = try await handler(params, WKScriptMessage())
        XCTAssertTrue(mockManager.reportExceptionCalled)
        XCTAssertEqual(mockManager.exceptionParams, params)
        XCTAssertNil(result)
    }

    @MainActor
    func testDismissToAddressBar_CallsGoToAddressBar() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "dismissToAddressBar"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.goToAddressBarCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testDismissToSettings_CallsGoToSettings() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "dismissToSettings"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.goToSettingsCalled)
        XCTAssertNil(result)
    }

    @MainActor
    func testRequestDockOptIn_CallsAddToDock() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "requestDockOptIn"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.addToDockCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testRequestImport_CallsImportData() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "requestImport"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.importDataCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testRequestSetAsDefault_CallsSetAsDefault() async throws {
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "requestSetAsDefault"))

        let result = try await handler([""], WKScriptMessage())
        XCTAssertTrue(mockManager.setAsDefaultCalled)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testSetBookmarksBar_CallsSetBookmarkBar() async throws {
        let randomBool = Bool.random()
        let params = ["enabled": randomBool]
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "setBookmarksBar"))

        let result = try await handler(params, WKScriptMessage())
        XCTAssertTrue(mockManager.setBookmarkBarCalled)
        XCTAssertEqual(mockManager.bookmarkBarVisible, randomBool)
        XCTAssertNil(result)
    }

    @MainActor
    func testSetSessionRestore_CallsSetSessionRestore() async throws {
        let randomBool = Bool.random()
        let params = ["enabled": randomBool]
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "setSessionRestore"))

        let result = try? await handler(params, WKScriptMessage())
        XCTAssertTrue(mockManager.setSessionRestoreCalled)
        XCTAssertEqual(mockManager.sessionRestoreEnabled, randomBool)
        XCTAssertNil(result)
    }

    @MainActor
    func testSetShowHome_CallsSetShowHomeButtonLeft() async throws {
        let randomBool = Bool.random()
        let params = ["enabled": randomBool]
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "setShowHomeButton"))

        let result = try await handler(params, WKScriptMessage())
        XCTAssertTrue(mockManager.setHomeButtonPositionCalled)
        XCTAssertEqual(mockManager.homeButtonVisible, randomBool)
        XCTAssertNil(result)
    }

    @MainActor
    func testStepCompleted_CallsStepCompleted() async throws {
        let randomStep = OnboardingSteps.allCases.randomElement()!
        let params = ["id": randomStep.rawValue]
        let handler = try XCTUnwrap(script.handler(forMethodNamed: "stepCompleted"))

        let result = try await handler(params, WKScriptMessage())
        XCTAssertEqual(mockManager.completedStep, randomStep)
        XCTAssertNil(result)
    }

}
