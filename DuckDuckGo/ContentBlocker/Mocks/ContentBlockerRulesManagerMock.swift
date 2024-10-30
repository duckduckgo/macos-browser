//
//  ContentBlockerRulesManagerMock.swift
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

import BrowserServicesKit
import Combine
import TrackerRadarKit

#if DEBUG

final class ContentBlockerRulesManagerMock: NSObject, ContentBlockerRulesManagerProtocol {
    func entity(forHost host: String) -> Entity? {
        return nil
    }

    func scheduleCompilation() -> BrowserServicesKit.ContentBlockerRulesManager.CompletionToken {
        BrowserServicesKit.ContentBlockerRulesManager.CompletionToken()
    }

    var currentMainRules: BrowserServicesKit.ContentBlockerRulesManager.Rules?

    var currentAttributionRules: BrowserServicesKit.ContentBlockerRulesManager.Rules?

    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> {
        updatesSubject.eraseToAnyPublisher()
    }

    let updatesSubject = PassthroughSubject<ContentBlockerRulesManager.UpdateEvent, Never>()

    var currentRules: [ContentBlockerRulesManager.Rules] = []

}

#endif
