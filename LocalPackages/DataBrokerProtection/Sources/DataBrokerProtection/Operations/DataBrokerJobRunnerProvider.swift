//
//  DataBrokerJobRunnerProvider.swift
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

protocol JobRunnerProvider {
    @MainActor func getJobRunner() -> WebJobRunner
}

struct DataBrokerJobRunnerProvider: JobRunnerProvider {
    var privacyConfigManager: PrivacyConfigurationManaging
    var contentScopeProperties: ContentScopeProperties
    var emailService: EmailServiceProtocol
    var captchaService: CaptchaServiceProtocol

    @MainActor
    func getJobRunner() -> WebJobRunner {
        DataBrokerJobRunner(privacyConfigManager: privacyConfigManager,
                                  contentScopeProperties: contentScopeProperties,
                                  emailService: emailService,
                                  captchaService: captchaService
        )
    }
}
