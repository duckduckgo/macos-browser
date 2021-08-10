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

final class UserContentController: WKUserContentController {
    private var blockingRulesUpdatedCancellable: AnyCancellable?

    public init(rulesPublisher: AnyPublisher<WKContentRuleList?, Never> = ContentBlockerRulesManager.shared.blockingRules) {
        super.init()

        installContentBlockingRules(publisher: rulesPublisher)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installContentBlockingRules(publisher: AnyPublisher<WKContentRuleList?, Never>) {
        blockingRulesUpdatedCancellable = publisher.receive(on: RunLoop.main).sink { [weak self] rules in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self,
                  let rules = rules
            else { return }

            self.removeAllContentRuleLists()
            if PrivacyConfigurationManager.shared.config.isEnabled(featureKey: .contentBlocking) {
                self.add(rules)
            }
        }
    }

}
