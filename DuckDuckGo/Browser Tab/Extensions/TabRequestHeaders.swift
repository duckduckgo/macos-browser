//
//  TabRequestHeaders.swift
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

import WebKit

struct TabRequestHeaders: NavigationResponder {

    struct Constants {
        static let ddgClientHeaderKey = "X-DuckDuckGo-Client"
        static let ddgClientHeaderValue = "macOS"
    }

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isForMainFrame,
              navigationAction.request.url?.isDuckDuckGo == true,
              navigationAction.request.value(forHTTPHeaderField: Constants.ddgClientHeaderKey) == nil,
              // TODO: check for .backForward for other navigations
              // TODO: When page in history is error (Failing) this is -1 (session restore) an not the backForward
              navigationAction.navigationType != .backForward
        else {
            return .next
        }

        var request = navigationAction.request
        request.setValue(Constants.ddgClientHeaderValue, forHTTPHeaderField: Constants.ddgClientHeaderKey)

        return .redirect(request: request)
    }

}
