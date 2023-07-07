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

protocol WebOperationRunner {

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile]
    func optOut(profileQuery: BrokerProfileQueryData, extractedProfile: ExtractedProfile) async throws
}

@MainActor
final class TestOperationRunner: WebOperationRunner {
    var privacyConfigManager: PrivacyConfigurationManaging
    var contentScopeProperties: ContentScopeProperties

    internal init(privacyConfigManager: PrivacyConfigurationManaging,
                  contentScopeProperties: ContentScopeProperties) {
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
    }

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile] {
        let scan = ScanOperation(privacyConfig: privacyConfigManager, prefs: contentScopeProperties, query: profileQuery)
        return try await scan.run(inputValue: ())
    }

    func optOut(profileQuery: BrokerProfileQueryData, extractedProfile: ExtractedProfile) async throws {
        let optOut = OptOutOperation(privacyConfig: privacyConfigManager, prefs: contentScopeProperties, query: profileQuery)
        try await optOut.run(inputValue: extractedProfile)
    }

    deinit {
        print("DEINIT")
    }
}
