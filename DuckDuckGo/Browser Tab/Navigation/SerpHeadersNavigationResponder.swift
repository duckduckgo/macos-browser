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

import Navigation
import Foundation

struct SerpHeadersNavigationResponder: NavigationResponder {

    static let headers = [
        "X-DuckDuckGo-Client": "macOS"
    ]

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard let mainFrame = navigationAction.mainFrameTarget,
              navigationAction.url.isDuckDuckGo,
              Self.headers.contains(where: { navigationAction.request.value(forHTTPHeaderField: $0.key) == nil }),
              !navigationAction.navigationType.isBackForward
        else {
            return .next
        }

        var request = navigationAction.request
        for (key, value) in Self.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return .redirect(mainFrame) { navigator in
            navigator.load(request)
        }
    }

}
