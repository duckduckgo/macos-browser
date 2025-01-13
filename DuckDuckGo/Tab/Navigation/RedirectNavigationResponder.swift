//
//  RedirectNavigationResponder.swift
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

import Navigation
import Foundation

struct RedirectNavigationResponder: NavigationResponder {

    private let redirectManager: SubscriptionRedirectManager

    init(redirectManager: SubscriptionRedirectManager) {
        self.redirectManager = redirectManager
    }

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard let mainFrame = navigationAction.mainFrameTarget, let redirectURL = redirectManager.redirectURL(for: navigationAction.url) else { return .next }

        return .redirect(mainFrame) { navigator in
            var request = navigationAction.request
            request.url = redirectURL
            navigator.load(request)
        }
    }
}
