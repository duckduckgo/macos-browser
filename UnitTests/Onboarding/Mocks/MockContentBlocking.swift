//
//  MockContentBlocking.swift
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

import Foundation
import BrowserServicesKit
import Combine
import Common
import TrackerRadarKit
@testable import DuckDuckGo_Privacy_Browser

class MockContentBlocking: ContentBlockingProtocol {
    var privacyConfigurationManager: PrivacyConfigurationManaging = MockPrivacyConfigurationManaging()

    var contentBlockingManager: ContentBlockerRulesManagerProtocol = MockContentBlockerRulesManagerProtocol()

    var trackerDataManager: TrackerDataManager = TrackerDataManager(etag: nil, data: nil, embeddedDataProvider: MockEmbeddedDataProvider(), errorReporting: nil)

    var tld: TLD = TLD()

    var contentBlockingAssetsPublisher: AnyPublisher<UserContentUpdating.NewContent, Never> = Empty<UserContentUpdating.NewContent, Never>(completeImmediately: false).eraseToAnyPublisher()
}

class MockEmbeddedDataProvider: EmbeddedDataProvider {
    var embeddedDataEtag: String = ""
    var embeddedData: Data = Data()
}

class MockPrivacyConfigurationManaging: PrivacyConfigurationManaging {
    var currentConfig: Data = Data()

    let updatesSubject = PassthroughSubject<Void, Never>()

    var updatesPublisher: AnyPublisher<Void, Never> {
        updatesSubject.eraseToAnyPublisher()
    }

    var privacyConfig: PrivacyConfiguration = MockPrivacyConfiguration()

    var mockConfig: MockPrivacyConfiguration {
        privacyConfig as! MockPrivacyConfiguration
    }

    var internalUserDecider: InternalUserDecider = InternalUserDeciderMock()

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        return PrivacyConfigurationManager.ReloadResult.downloaded
    }

}

class MockContentBlockerRulesManagerProtocol: ContentBlockerRulesManagerProtocol {
    func entity(forHost host: String) -> Entity? {
        return nil
    }

    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> = Empty<ContentBlockerRulesManager.UpdateEvent, Never>(completeImmediately: false).eraseToAnyPublisher()

    var currentRules: [BrowserServicesKit.ContentBlockerRulesManager.Rules] = []

    func scheduleCompilation() -> ContentBlockerRulesManager.CompletionToken {
        return ContentBlockerRulesManager.CompletionToken(StaticString())
    }

    var currentMainRules: ContentBlockerRulesManager.Rules?

    var currentAttributionRules: ContentBlockerRulesManager.Rules?
}
