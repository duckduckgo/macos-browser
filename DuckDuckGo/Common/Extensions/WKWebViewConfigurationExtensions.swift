//
//  WKWebViewConfigurationExtensions.swift
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

extension WKWebViewConfiguration {

    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.applyStandardConfiguration()
        return configuration
    }

    func applyStandardConfiguration(persistent: Bool = true) {
        if !self.userContentController.userScripts.isEmpty {
            self.userContentController = WKUserContentController()
        }
        websiteDataStore = WKWebsiteDataStore.default()
        allowsAirPlayForMediaPlayback = true
        preferences.setValue(true, forKey: "fullScreenEnabled")
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        installContentBlockingRules()
     }

    private func installContentBlockingRules() {
        userContentController.installContentBlockingRules()
    }

}

extension WKUserContentController {

    func installContentBlockingRules() {
        ContentBlockerRulesManager.shared.blockingRules.sink { [weak self] rules in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self,
                  let rules = rules
            else { return }

            self.removeAllContentRuleLists()
            self.add(rules)

        }.store(in: &self.lifetimeDisposeBag)
    }

}
