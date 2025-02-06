//
//  DataBrokerOperationActionTests.swift
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

import BrowserServicesKit
import Combine
import Foundation
import XCTest

@testable import DataBrokerProtection

final class DataBrokerOperationActionTests: XCTestCase {
    let webViewHandler = WebViewHandlerMock()
    let emailService = EmailServiceMock()
    let captchaService = CaptchaServiceMock()
    let pixelHandler = MockDataBrokerProtectionPixelsHandler()
    let stageCalulator = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: MockDataBrokerProtectionPixelsHandler())

    override func tearDown() async throws {
        webViewHandler.reset()
        emailService.reset()
        captchaService.reset()
    }

    func testWhenEmailConfirmationActionSucceeds_thenExtractedLinkIsOpened() async {
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1, dataSource: nil)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let extractedProfile = ExtractedProfile(email: "test@duck.com")
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: extractedProfile, webViewHandler: webViewHandler)
            XCTAssertEqual(webViewHandler.wasLoadCalledWithURL?.absoluteString, "https://www.duckduckgo.com")
            XCTAssertTrue(webViewHandler.wasFinishCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenEmailConfirmationActionHasNoEmail_thenNoURLIsLoadedAndWebViewFinishes() async {
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1, dataSource: nil)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let noEmailExtractedProfile = ExtractedProfile()
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: noEmailExtractedProfile, webViewHandler: webViewHandler)
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertNil(webViewHandler.wasLoadCalledWithURL?.absoluteString)
            XCTAssertTrue(webViewHandler.wasFinishCalled)

            if let error = error as? DataBrokerProtectionError, case .emailError(.cantFindEmail) = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenOnEmailConfirmationActionEmailServiceThrows_thenOperationThrows() async {
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1, dataSource: nil)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let extractedProfile = ExtractedProfile(email: "test@duck.com")
        emailService.shouldThrow = true
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: extractedProfile, webViewHandler: webViewHandler)
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertNil(webViewHandler.wasLoadCalledWithURL?.absoluteString)
            XCTAssertTrue(webViewHandler.wasFinishCalled)

            if let error = error as? DataBrokerProtectionError, case .emailError(nil) = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenActionNeedsEmail_thenExtractedProfileEmailIsSet() async {
        let fillFormAction = FillFormAction(id: "1", actionType: .fillForm, selector: "#test", elements: [.init(type: "email", selector: "#email", parent: nil, multiple: nil, min: nil, max: nil, failSilently: nil)], dataSource: nil)
        let step = Step(type: .optOut, actions: [fillFormAction])
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler
        sut.extractedProfile = ExtractedProfile()

        await sut.runNextAction(fillFormAction)

        XCTAssertEqual(sut.extractedProfile?.email, "test@duck.com")
        XCTAssertTrue(webViewHandler.wasExecuteCalledForUserData)
    }

    func testWhenGetEmailServiceFails_thenOperationThrows() async {
        let fillFormAction = FillFormAction(id: "1", actionType: .fillForm, selector: "#test", elements: [.init(type: "email", selector: "#email", parent: nil, multiple: nil, min: nil, max: nil, failSilently: nil)], dataSource: nil)
        let step = Step(type: .optOut, actions: [fillFormAction])
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        emailService.shouldThrow = true

        do {
            _ = try await sut.run(inputValue: ExtractedProfile(), webViewHandler: webViewHandler)
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertTrue(webViewHandler.wasFinishCalled)

            if let error = error as? DataBrokerProtectionError, case .emailError(nil) = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenClickActionSucceeds_thenWeWaitForWebViewToLoad() async {
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            clickAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.success(actionId: "1", actionType: .click)

        XCTAssertFalse(webViewHandler.wasWaitForWebViewLoadCalled)
        XCTAssertTrue(webViewHandler.wasFinishCalled)
    }

    func testWhenAnActionThatIsNotClickSucceeds_thenWeDoNotWaitForWebViewToLoad() async {
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.success(actionId: "1", actionType: .expectation)

        XCTAssertFalse(webViewHandler.wasWaitForWebViewLoadCalled)
        XCTAssertTrue(webViewHandler.wasFinishCalled)
    }

    func testWhenSolveCaptchaActionIsRun_thenCaptchaIsResolved() async {
        let solveCaptchaAction = SolveCaptchaAction(id: "1", actionType: .solveCaptcha, selector: "g-captcha", dataSource: nil)
        let step = Step(type: .optOut, actions: [solveCaptchaAction])
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler
        sut.actionsHandler = ActionsHandler(step: step)
        sut.actionsHandler?.captchaTransactionId = "transactionId"

        await sut.runNextAction(solveCaptchaAction)

        XCTAssert(webViewHandler.wasExecuteCalledForSolveCaptcha)
    }

    func testWhenSolveCapchaActionFailsToSubmitDataToTheBackend_thenOperationFails() async {
        let solveCaptchaAction = SolveCaptchaAction(id: "1", actionType: .solveCaptcha, selector: "g-captcha", dataSource: nil)
        let step = Step(type: .optOut, actions: [solveCaptchaAction])
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        let actionsHandler = ActionsHandler(step: step)
        actionsHandler.captchaTransactionId = "transactionId"
        captchaService.shouldThrow = true

        do {
            _ = try await sut.run(inputValue: ExtractedProfile(), webViewHandler: webViewHandler, actionsHandler: actionsHandler)
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? DataBrokerProtectionError, case .captchaServiceError(.nilDataWhenFetchingCaptchaResult) = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenCaptchaInformationIsReturned_thenWeSubmitItTotTheBackend() async {
        let getCaptchaResponse = GetCaptchaInfoResponse(siteKey: "siteKey", url: "url", type: "recaptcha")
        let step = Step(type: .optOut, actions: [Action]())
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler
        sut.actionsHandler = ActionsHandler(step: step)

        await sut.captchaInformation(captchaInfo: getCaptchaResponse)

        XCTAssertTrue(captchaService.wasSubmitCaptchaInformationCalled)
        XCTAssert(webViewHandler.wasFinishCalled)
    }

    func testWhenCaptchaInformationFailsToBeSubmitted_thenTheOperationFails() async {
        let getCaptchaResponse = GetCaptchaInfoResponse(siteKey: "siteKey", url: "url", type: "recaptcha")
        let step = Step(type: .optOut, actions: [Action]())
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.retriesCountOnError = 0
        captchaService.shouldThrow = true
        sut.webViewHandler = webViewHandler
        sut.actionsHandler = ActionsHandler(step: step)

        await sut.captchaInformation(captchaInfo: getCaptchaResponse)

        XCTAssertFalse(captchaService.wasSubmitCaptchaInformationCalled)
        XCTAssert(webViewHandler.wasFinishCalled)
    }

    func testWhenRunningActionWithoutExtractedProfile_thenExecuteIsCalledWithProfileData() async {
        let expectationAction = ExpectationAction(id: "1", actionType: .expectation, expectations: [Item](), dataSource: nil, actions: nil)
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.runNextAction(expectationAction)

        XCTAssertTrue(webViewHandler.wasExecuteCalledForUserData)
    }

    func testWhenLoadURLDelegateIsCalled_thenCorrectMethodIsExecutedOnWebViewHandler() async {
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.loadURL(url: URL(string: "https://www.duckduckgo.com")!)

        XCTAssertEqual(webViewHandler.wasLoadCalledWithURL?.absoluteString, "https://www.duckduckgo.com")
    }

    func testWhenGetCaptchaActionRuns_thenStageIsSetToCaptchaParse() async {
        let mockStageCalculator = MockStageDurationCalculator()
        let captchaAction = GetCaptchaInfoAction(id: "1", actionType: .getCaptchaInfo, selector: "captcha", dataSource: nil)
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: mockStageCalculator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        await sut.runNextAction(captchaAction)

        XCTAssertEqual(mockStageCalculator.stage, .captchaParse)
    }

    func testWhenClickActionRuns_thenStageIsSetToSubmit() async {
        let mockStageCalculator = MockStageDurationCalculator()
        let clickAction = ClickAction(id: "1", actionType: .click, elements: [PageElement](), dataSource: nil, choices: nil, default: nil, hasDefault: false)
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: mockStageCalculator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        await sut.runNextAction(clickAction)

        XCTAssertEqual(mockStageCalculator.stage, .fillForm)
    }

    func testWhenExpectationActionRuns_thenStageIsSetToSubmit() async {
        let mockStageCalculator = MockStageDurationCalculator()
        let expectationAction = ExpectationAction(id: "1", actionType: .expectation, expectations: [Item](), dataSource: nil, actions: nil)
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: mockStageCalculator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        await sut.runNextAction(expectationAction)

        XCTAssertEqual(mockStageCalculator.stage, .submit)
    }

    func testWhenFillFormActionRuns_thenStageIsSetToFillForm() async {
        let mockStageCalculator = MockStageDurationCalculator()
        let fillFormAction = FillFormAction(id: "1", actionType: .fillForm, selector: "", elements: [PageElement](), dataSource: nil)
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            captchaService: captchaService,
            operationAwaitTime: 0,
            stageCalculator: mockStageCalculator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        await sut.runNextAction(fillFormAction)

        XCTAssertEqual(mockStageCalculator.stage, .fillForm)
    }

    func testWhenLoadUrlOnSpokeo_thenSetCookiesIsCalled() async {
        let mockCookieHandler = MockCookieHandler()
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(url: "spokeo.com"),
            emailService: emailService,
            captchaService: captchaService,
            cookieHandler: mockCookieHandler,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        mockCookieHandler.cookiesToReturn = [.init()]
        sut.webViewHandler = webViewHandler
        await sut.loadURL(url: URL(string: "www.test.com")!)

        XCTAssertTrue(webViewHandler.wasSetCookiesCalled)
    }

    func testWhenLoadUrlOnOtherBroker_thenSetCookiesIsNotCalled() async {
        let mockCookieHandler = MockCookieHandler()
        let sut = OptOutJob(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(url: "verecor.com"),
            emailService: emailService,
            captchaService: captchaService,
            cookieHandler: mockCookieHandler,
            operationAwaitTime: 0,
            stageCalculator: stageCalulator,
            pixelHandler: pixelHandler,
            sleepObserver: FakeSleepObserver(),
            shouldRunNextStep: { true }
        )

        mockCookieHandler.cookiesToReturn = [.init()]
        sut.webViewHandler = webViewHandler
        await sut.loadURL(url: URL(string: "www.test.com")!)

        XCTAssertFalse(webViewHandler.wasSetCookiesCalled)
    }
}
