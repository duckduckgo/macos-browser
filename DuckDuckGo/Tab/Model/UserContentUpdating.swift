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
import Common
import BrowserServicesKit
import UserScript
import Configuration

extension ContentBlockerRulesIdentifier.Difference {
    static let notification = ContentBlockerRulesIdentifier.Difference(rawValue: 1 << 8)
}

final class UserContentUpdating {

    private typealias Update = ContentBlockerRulesManager.UpdateEvent
    struct NewContent: UserContentControllerNewContent {
        let rulesUpdate: ContentBlockerRulesManager.UpdateEvent
        let sourceProvider: ScriptSourceProviding

        var makeUserScripts: @MainActor (ScriptSourceProviding) -> UserScripts {
            { sourceProvider in
                UserScripts(with: sourceProvider)
            }
        }
    }

    @Published private var bufferedValue: NewContent?
    private var cancellable: AnyCancellable?

    private(set) var userContentBlockingAssets: AnyPublisher<UserContentUpdating.NewContent, Never>!

    @MainActor
    init(contentBlockerRulesManager: ContentBlockerRulesManagerProtocol,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         trackerDataManager: TrackerDataManager,
         configStorage: ConfigurationStoring,
         webTrackingProtectionPreferences: WebTrackingProtectionPreferences,
         tld: TLD) {

        let makeValue: (Update) -> NewContent = { rulesUpdate in
            let sourceProvider = ScriptSourceProvider(configStorage: configStorage,
                                                      privacyConfigurationManager: privacyConfigurationManager,
                                                      webTrackingProtectionPreferences: webTrackingProtectionPreferences,
                                                      contentBlockingManager: contentBlockerRulesManager,
                                                      trackerDataManager: trackerDataManager,
                                                      tld: tld)
            return NewContent(rulesUpdate: rulesUpdate, sourceProvider: sourceProvider)
        }

        func onNotificationWithInitial(_ name: Notification.Name) -> AnyPublisher<Notification, Never> {
            return NotificationCenter.default.publisher(for: name)
                .prepend([Notification(name: .init(rawValue: "initial"))])
                .eraseToAnyPublisher()
        }

        func combine(_ update: Update, _ notification: Notification) -> Update {
            var changes = update.changes
            changes[notification.name.rawValue] = .notification
            return Update(rules: update.rules, changes: changes, completionTokens: update.completionTokens)
        }

        // 1. Collect updates from ContentBlockerRulesManager and generate UserScripts based on its output
        cancellable = contentBlockerRulesManager.updatesPublisher
            // regenerate UserScripts on gpcEnabled preference updated
            .combineLatest(webTrackingProtectionPreferences.$isGPCEnabled)
            .map { $0.0 } // drop gpcEnabled value: $0.1
            .combineLatest(onNotificationWithInitial(.autofillUserSettingsDidChange), combine)
            .combineLatest(onNotificationWithInitial(.autofillScriptDebugSettingsDidChange), combine)
            // DefaultScriptSourceProvider instance should be created once per rules/config change and fed into UserScripts initialization
            .map(makeValue)
            .assign(to: \.bufferedValue, onWeaklyHeld: self) // buffer latest update value

        // 2. Publish ContentBlockingAssets(Rules+Scripts) for WKUserContentController per subscription
        self.userContentBlockingAssets = $bufferedValue
            .compactMap { $0 } // drop initial nil
            .eraseToAnyPublisher()
    }

}
