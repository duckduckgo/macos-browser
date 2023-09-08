//
//  WebOperationRunner.swift
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
import BrowserServicesKit
import Common

protocol WebOperationRunner {

<<<<<<< HEAD
    func scan(_ profileQuery: BrokerProfileQueryData,
              showWebView: Bool,
              shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile]

    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
                showWebView: Bool,
                shouldRunNextStep: @escaping () -> Bool) async throws
=======
    func scan(_ profileQuery: BrokerProfileQueryData, stageCalculator: DataBrokerProtectionStageDurationCalculator, showWebView: Bool) async throws -> [ExtractedProfile]
    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
                stageCalculator: DataBrokerProtectionStageDurationCalculator,
                showWebView: Bool) async throws
>>>>>>> 81976607 (Inject stage calculator to operations)
}

extension WebOperationRunner {

<<<<<<< HEAD
    func scan(_ profileQuery: BrokerProfileQueryData,
              shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile] {

        try await scan(profileQuery,
                       showWebView: false,
                       shouldRunNextStep: shouldRunNextStep)
    }

    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
                shouldRunNextStep: @escaping () -> Bool) async throws {

        try await optOut(profileQuery: profileQuery,
                         extractedProfile: extractedProfile,
                         showWebView: false,
                         shouldRunNextStep: shouldRunNextStep)
=======
    func scan(_ profileQuery: BrokerProfileQueryData, stageCalculator: DataBrokerProtectionStageDurationCalculator) async throws -> [ExtractedProfile] {
        try await scan(profileQuery, stageCalculator: stageCalculator, showWebView: false)
    }

    func optOut(profileQuery: BrokerProfileQueryData, extractedProfile: ExtractedProfile, stageCalculator: DataBrokerProtectionStageDurationCalculator) async throws {
        try await optOut(profileQuery: profileQuery, extractedProfile: extractedProfile, stageCalculator: stageCalculator, showWebView: false)
>>>>>>> 81976607 (Inject stage calculator to operations)
    }
}

@MainActor
final class DataBrokerOperationRunner: WebOperationRunner {
    let privacyConfigManager: PrivacyConfigurationManaging
    let contentScopeProperties: ContentScopeProperties
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol

    internal init(privacyConfigManager: PrivacyConfigurationManaging,
                  contentScopeProperties: ContentScopeProperties,
                  emailService: EmailServiceProtocol,
                  captchaService: CaptchaServiceProtocol) {
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
        self.emailService = emailService
        self.captchaService = captchaService
    }

<<<<<<< HEAD
    func scan(_ profileQuery: BrokerProfileQueryData,
              showWebView: Bool,
              shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile] {

=======
    func scan(_ profileQuery: BrokerProfileQueryData, stageCalculator: DataBrokerProtectionStageDurationCalculator, showWebView: Bool) async throws -> [ExtractedProfile] {
>>>>>>> 81976607 (Inject stage calculator to operations)
        let scan = ScanOperation(
            privacyConfig: privacyConfigManager,
            prefs: contentScopeProperties,
            query: profileQuery,
            emailService: emailService,
            captchaService: captchaService,
            shouldRunNextStep: shouldRunNextStep
        )
<<<<<<< HEAD
        return try await scan.run(inputValue: (),
                                  showWebView: showWebView)
=======
        return try await scan.run(inputValue: (), stageCalculator: stageCalculator, showWebView: showWebView)
>>>>>>> 81976607 (Inject stage calculator to operations)
    }

    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
<<<<<<< HEAD
                showWebView: Bool,
                shouldRunNextStep: @escaping () -> Bool) async throws {

=======
                stageCalculator: DataBrokerProtectionStageDurationCalculator,
                showWebView: Bool) async throws {
>>>>>>> 81976607 (Inject stage calculator to operations)
        let optOut = OptOutOperation(
            privacyConfig: privacyConfigManager,
            prefs: contentScopeProperties,
            query: profileQuery,
            emailService: emailService,
            captchaService: captchaService,
            shouldRunNextStep: shouldRunNextStep
        )
<<<<<<< HEAD
        try await optOut.run(inputValue: extractedProfile,
                             showWebView: showWebView)
=======
        try await optOut.run(inputValue: extractedProfile, stageCalculator: stageCalculator, showWebView: showWebView)
>>>>>>> 81976607 (Inject stage calculator to operations)
    }

    deinit {
        os_log("WebOperationRunner Deinit", log: .dataBrokerProtection)
    }
}
