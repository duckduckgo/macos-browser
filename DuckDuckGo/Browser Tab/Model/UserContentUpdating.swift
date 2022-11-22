//
//  UserContentUpdating.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import UserScript

final class UserContentUpdating {

    struct NewContent: UserContentControllerNewContent {
        let rulesUpdate: ContentBlockerRulesManager.UpdateEvent
        let sourceProvider: ScriptSourceProviding
        var makeUserScripts: (ScriptSourceProviding) -> UserScripts { return UserScripts.init(with:) }
    }

    @Published private var bufferedValue: NewContent?
    private var cancellable: AnyCancellable?

    private(set) var userContentBlockingAssets: AnyPublisher<UserContentUpdating.NewContent, Never>!

    init(contentBlockerRulesManager: ContentBlockerRulesManagerProtocol,
         privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager,
         configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared,
         privacySecurityPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared) {

        let makeValue: (ContentBlockerRulesManager.UpdateEvent) -> NewContent = { rulesUpdate in
            let sourceProvider = DefaultScriptSourceProvider(configStorage: configStorage,
                                                             privacyConfigurationManager: privacyConfigurationManager,
                                                             privacySettings: privacySecurityPreferences,
                                                             contentBlockingManager: contentBlockerRulesManager)
            return NewContent(rulesUpdate: rulesUpdate, sourceProvider: sourceProvider)
        }

        // 1. Collect updates from ContentBlockerRulesManager and generate UserScripts based on its output
        cancellable = contentBlockerRulesManager.updatesPublisher
            // regenerate UserScripts on gpcEnabled preference updated
            .combineLatest(privacySecurityPreferences.$gpcEnabled)
            .map { $0.0 } // drop gpcEnabled value: $0.1
            // DefaultScriptSourceProvider instance should be created once per rules/config change and fed into UserScripts initialization
            .map(makeValue)
            .assign(to: \.bufferedValue, onWeaklyHeld: self) // buffer latest update value

        // 2. Publish ContentBlockingAssets(Rules+Scripts) for WKUserContentController per subscription
        self.userContentBlockingAssets = $bufferedValue
            .compactMap { $0 } // drop initial nil
            .eraseToAnyPublisher()
    }

}
