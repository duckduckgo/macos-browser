//
//  SerpHeadersNavigationResponder.swift
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
import Navigation
import Foundation

struct SerpHeadersNavigationResponder: NavigationResponder {

    static let headers = [
        "X-DuckDuckGo-Client": "macOS"
    ]

    var internalUserDecider: InternalUserDecider = NSApp.delegateTyped.internalUserDecider
    var statisticsStore: StatisticsStore = LocalStatisticsStore()

    private var headers: [String: String] {
        Self.headers
    }

    private var parameters: [String: String] {
        // https://app.asana.com/0/0/1205979030848528/f
        // For internal users only, pass ATB variant to SERP to trigger the privacy reminder.
        // add `wb` to the atb param, like so: &atb=v444-wb
        if internalUserDecider.isInternalUser, let atbWithVariant = statisticsStore.atbWithVariant {
            return [URL.DuckDuckGoParameters.ATB.atb: atbWithVariant + "-wb"]
        }
        return [:]
    }

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        lazy var headers = self.headers
        lazy var parameters = self.parameters

        guard navigationAction.isForMainFrame,
              navigationAction.url.isDuckDuckGo,
              !navigationAction.navigationType.isBackForward else { return .next }

        var request = navigationAction.request
        if headers.contains(where: { navigationAction.request.value(forHTTPHeaderField: $0.key) == nil }) {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if parameters.contains(where: { navigationAction.url.getParameter(named: $0.key) != $0.value }) {
            request.url = request.url!
                .removingParameters(named: Set(parameters.keys))
                .appendingParameters(parameters)
        }

        guard request != navigationAction.request else { return .next }

        return .redirectInvalidatingBackItemIfNeeded(navigationAction) { navigator in
            navigator.load(request)
        }
    }

}
