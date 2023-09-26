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

import XCTest
import Foundation
import BrowserServicesKit
import Combine
@testable import DataBrokerProtection

final class DataBrokerOperationActionTests: XCTestCase {
    let webViewHandler = WebViewHandlerMock()
    let emailService = EmailServiceMock()
    let captchaService = CaptchaServiceMock()
    let stageCalulator = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", handler: MockDataBrokerProtectionPixelsHandler())

    override func tearDown() async throws {
        webViewHandler.reset()
        emailService.reset()
        captchaService.reset()
    }

    func testWhenEmailConfirmationActionSucceeds_thenExtractedLinkIsOpened() async {
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let extractedProfile = ExtractedProfile(email: "test@duck.com")
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: extractedProfile, webViewHandler: webViewHandler, stageCalculator: stageCalulator)
            XCTAssertEqual(webViewHandler.wasLoadCalledWithURL?.absoluteString, "https://www.duckduckgo.com")
            XCTAssertTrue(webViewHandler.wasFinishCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenEmailConfirmationActionHasNoEmail_thenNoURLIsLoadedAndWebViewFinishes() async {
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let noEmailExtractedProfile = ExtractedProfile()
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: noEmailExtractedProfile, webViewHandler: webViewHandler, stageCalculator: stageCalulator)
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
        let emailConfirmationAction = EmailConfirmationAction(id: "", actionType: .emailConfirmation, pollingTime: 1)
        let step = Step(type: .optOut, actions: [emailConfirmationAction])
        let extractedProfile = ExtractedProfile(email: "test@duck.com")
        emailService.shouldThrow = true
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )

        do {
            _ = try await sut.run(inputValue: extractedProfile, webViewHandler: webViewHandler, stageCalculator: stageCalulator)
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
        let fillFormAction = FillFormAction(id: "1", actionType: .fillForm, selector: "#test", elements: [.init(type: "email", selector: "#email")])
        let step = Step(type: .optOut, actions: [fillFormAction])
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler
        sut.extractedProfile = ExtractedProfile()

        await sut.runNextAction(fillFormAction)

        XCTAssertEqual(sut.extractedProfile?.email, "test@duck.com")
        XCTAssertTrue(webViewHandler.wasExecuteCalledForExtractedProfile)
    }

    func testWhenGetEmailServiceFails_thenOperationThrows() async {
        let fillFormAction = FillFormAction(id: "1", actionType: .fillForm, selector: "#test", elements: [.init(type: "email", selector: "#email")])
        let step = Step(type: .optOut, actions: [fillFormAction])
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        emailService.shouldThrow = true

        do {
            _ = try await sut.run(inputValue: ExtractedProfile(), webViewHandler: webViewHandler, stageCalculator: stageCalulator)
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
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.success(actionId: "1", actionType: .click)

        XCTAssertTrue(webViewHandler.wasWaitForWebViewLoadCalled)
        XCTAssertTrue(webViewHandler.wasFinishCalled)
    }

    func testWhenAnActionThatIsNotClickSucceeds_thenWeDoNotWaitForWebViewToLoad() async {
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.success(actionId: "1", actionType: .expectation)

        XCTAssertFalse(webViewHandler.wasWaitForWebViewLoadCalled)
        XCTAssertTrue(webViewHandler.wasFinishCalled)
    }

    func testWhenSolveCaptchaActionIsRun_thenCaptchaIsResolved() async {
        let solveCaptchaAction = SolveCaptchaAction(id: "1", actionType: .solveCaptcha, selector: "g-captcha")
        let step = Step(type: .optOut, actions: [solveCaptchaAction])
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            captchaService: captchaService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler
        sut.actionsHandler = ActionsHandler(step: step)
        sut.actionsHandler?.captchaTransactionId = "transactionId"

        await sut.runNextAction(solveCaptchaAction)

        XCTAssert(webViewHandler.wasExecuteCalledForSolveCaptcha)
    }

    func testWhenSolveCapchaActionFailsToSubmitDataToTheBackend_thenOperationFails() async {
        let solveCaptchaAction = SolveCaptchaAction(id: "1", actionType: .solveCaptcha, selector: "g-captcha")
        let step = Step(type: .optOut, actions: [solveCaptchaAction])
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(with: [step]),
            captchaService: captchaService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        let actionsHandler = ActionsHandler(step: step)
        actionsHandler.captchaTransactionId = "transactionId"
        captchaService.shouldThrow = true

        do {
            _ = try await sut.run(inputValue: ExtractedProfile(), webViewHandler: webViewHandler, actionsHandler: actionsHandler, stageCalculator: stageCalulator)
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
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            captchaService: captchaService,
            operationAwaitTime: 0,
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
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            captchaService: captchaService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        captchaService.shouldThrow = true
        sut.webViewHandler = webViewHandler
        sut.actionsHandler = ActionsHandler(step: step)

        await sut.captchaInformation(captchaInfo: getCaptchaResponse)

        XCTAssertFalse(captchaService.wasSubmitCaptchaInformationCalled)
        XCTAssert(webViewHandler.wasFinishCalled)
    }

    func testWhenRunningActionWithoutExtractedProfile_thenExecuteIsCalledWithProfileData() async {
        let expectationAction = ExpectationAction(id: "1", actionType: .expectation, expectations: [Item]())
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.runNextAction(expectationAction)

        XCTAssertTrue(webViewHandler.wasExecuteCalledForProfileData)
    }

    func testWhenLoadURLDelegateIsCalled_thenCorrectMethodIsExecutedOnWebViewHandler() async {
        let sut = OptOutOperation(
            privacyConfig: PrivacyConfigurationManagingMock(),
            prefs: ContentScopeProperties.mock,
            query: BrokerProfileQueryData.mock(),
            emailService: emailService,
            operationAwaitTime: 0,
            shouldRunNextStep: { true }
        )
        sut.webViewHandler = webViewHandler

        await sut.loadURL(url: URL(string: "https://www.duckduckgo.com")!)

        XCTAssertEqual(webViewHandler.wasLoadCalledWithURL?.absoluteString, "https://www.duckduckgo.com")
    }
}
