//
//  Mocks.swift
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

import Foundation
import Combine
import BrowserServicesKit
@testable import DataBrokerProtection

extension BrokerProfileQueryData {
    static func mock(with steps: [Step] = [Step]()) -> BrokerProfileQueryData {
        BrokerProfileQueryData(
            id: UUID(),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 50),
            dataBroker: DataBroker(
                name: "test",
                steps: steps,
                schedulingConfig: DataBrokerScheduleConfig.mock
            )
        )
    }
}

extension DataBrokerScheduleConfig {
    static var mock: DataBrokerScheduleConfig {
        DataBrokerScheduleConfig(retryError: TimeInterval.pi, confirmOptOutScan: TimeInterval.pi, maintenanceScan: TimeInterval.pi)
    }
}

final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {
    var currentConfig: Data = Data()

    var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

    var privacyConfig: BrowserServicesKit.PrivacyConfiguration = PrivacyConfigurationMock()

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        .downloaded
    }
}

final class PrivacyConfigurationMock: PrivacyConfiguration {

    var identifier: String = "mock"

    var userUnprotectedDomains = [String]()

    var tempUnprotectedDomains = [String]()

    var trackerAllowlist = BrowserServicesKit.PrivacyConfigurationData.TrackerAllowlist(entries: [String: [PrivacyConfigurationData.TrackerAllowlist.Entry]](), state: "mock")

    func isEnabled(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
        false
    }

    func isSubfeatureEnabled(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
        false
    }

    func exceptionsList(forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> [String] {
        [String]()
    }

    func isFeature(_ feature: BrowserServicesKit.PrivacyFeature, enabledForDomain: String?) -> Bool {
        false
    }

    func isProtected(domain: String?) -> Bool {
        false
    }

    func isUserUnprotected(domain: String?) -> Bool {
        false
    }

    func isTempUnprotected(domain: String?) -> Bool {
        false
    }

    func isInExceptionList(domain: String?, forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> Bool {
        false
    }

    func settings(for feature: BrowserServicesKit.PrivacyFeature) -> BrowserServicesKit.PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        [String: Any]()
    }

    func userEnabledProtection(forDomain: String) {

    }

    func userDisabledProtection(forDomain: String) {

    }

}

extension ContentScopeProperties {
    static var mock: ContentScopeProperties {
        ContentScopeProperties(
            gpcEnabled: false,
            sessionKey: "sessionKey",
            featureToggles: ContentScopeFeatureToggles.mock
        )
    }
}

extension ContentScopeFeatureToggles {

    static var mock: ContentScopeFeatureToggles {
        ContentScopeFeatureToggles(
            emailProtection: false,
            emailProtectionIncontextSignup: false,
            credentialsAutofill: false,
            identitiesAutofill: false,
            creditCardsAutofill: false,
            credentialsSaving: false,
            passwordGeneration: false,
            inlineIconCredentials: false,
            thirdPartyCredentialsProvider: false
        )
    }
}

final class WebViewHandlerMock: NSObject, WebViewHandler {

    var wasInitializeWebViewCalled = false
    var wasLoadCalledWithURL: URL?
    var wasWaitForWebViewLoadCalled = false
    var wasFinishCalled = false
    var wasExecuteCalledForExtractedProfile = false
    var wasExecuteCalledForProfileData = false
    var wasExecuteCalledForSolveCaptcha = false

    func initializeWebView(debug: Bool) async {
        wasInitializeWebViewCalled = true
    }

    func load(url: URL) async throws {
        wasLoadCalledWithURL = url
    }

    func waitForWebViewLoad(timeoutInSeconds: Int) async throws {
        wasWaitForWebViewLoadCalled = true
    }

    func finish() async {
        wasFinishCalled = true
    }

    func execute(action: DataBrokerProtection.Action, data: DataBrokerProtection.CCFRequestData) async {
        switch data {
        case .profile:
            wasExecuteCalledForExtractedProfile = false
            wasExecuteCalledForSolveCaptcha = false
            wasExecuteCalledForProfileData = true
        case .solveCaptcha:
            wasExecuteCalledForExtractedProfile = false
            wasExecuteCalledForSolveCaptcha = true
            wasExecuteCalledForProfileData = false
        case.extractedProfile:
            wasExecuteCalledForExtractedProfile = true
            wasExecuteCalledForSolveCaptcha = false
            wasExecuteCalledForProfileData = false
        }
    }

    func reset() {
        wasInitializeWebViewCalled = false
        wasLoadCalledWithURL = nil
        wasWaitForWebViewLoadCalled = false
        wasFinishCalled = false
        wasExecuteCalledForExtractedProfile = false
        wasExecuteCalledForSolveCaptcha = false
        wasExecuteCalledForProfileData = false
    }
}

final class EmailServiceMock: EmailServiceProtocol {
    var shouldThrow: Bool = false

    func getEmail() async throws -> String {
        if shouldThrow {
            throw DataBrokerProtectionError.emailError(nil)
        }

        return "test@duck.com"
    }

    func getConfirmationLink(from email: String, numberOfRetries: Int, pollingIntervalInSeconds: Int) async throws -> URL {
        if shouldThrow {
            throw DataBrokerProtectionError.emailError(nil)
        }

        return URL(string: "https://www.duckduckgo.com")!
    }

    func reset() {
        shouldThrow = false
    }
}

final class CaptchaServiceMock: CaptchaServiceProtocol {

    var wasSubmitCaptchaInformationCalled = false
    var wasSubmitCaptchaToBeResolvedCalled = false
    var shouldThrow = false

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse, retries: Int) async throws -> CaptchaTransactionId {
        if shouldThrow {
            throw CaptchaServiceError.errorWhenSubmittingCaptcha
        }

        wasSubmitCaptchaInformationCalled = true

        return "transactionID"
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId, retries: Int, pollingInterval: Int) async throws -> CaptchaResolveData {
        if shouldThrow {
            throw CaptchaServiceError.errorWhenFetchingCaptchaResult
        }

        wasSubmitCaptchaToBeResolvedCalled = true

        return CaptchaResolveData()
    }

    func reset() {
        wasSubmitCaptchaInformationCalled = false
        wasSubmitCaptchaToBeResolvedCalled = false
    }
}
