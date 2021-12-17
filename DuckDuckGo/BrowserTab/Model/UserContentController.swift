//
//  UserContentController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import WebKit
import Combine
import BrowserServicesKit

final class UserContentController: WKUserContentController {
    private var blockingRulesUpdatedCancellable: AnyCancellable?
    
    let privacyConfigurationManager: PrivacyConfigurationManager

    public init(rulesPublisher: ContentBlockingUpdating.NewRulesPublisher = ContentBlocking.contentBlockingUpdating.contentBlockingRules,
                privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
        super.init()

        installContentBlockingRules(publisher: rulesPublisher)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installContentBlockingRules(publisher: ContentBlockingUpdating.NewRulesPublisher) {
        blockingRulesUpdatedCancellable = publisher.receive(on: RunLoop.main).sink { [weak self] newRules in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self,
                  let newRules = newRules
            else { return }

            // self.removeAllContentRuleLists()
            self.remove(newRules.rules.rulesList) // LDA TODO temporarily, don't remove all rules
            if self.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
                for rules in newRules.rules {
                    self.add(rules.rulesList)
                }
            }
        }
    }

}
