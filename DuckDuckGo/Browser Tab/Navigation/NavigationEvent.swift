//
//  NavigationEvent.swift
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
import WebKit

typealias NavigationHistory = [NavigationEvent]

enum NavigationEvent {

    // Expectation
    case willGoToBackForwardListItem(WKBackForwardListItem, inPageCache: Bool)

    case willRequestNewWebView(url: URL, target: TargetWindowName?, windowFeatures: WindowFeatures?)

    // Decision
    case decidePolicyForNavigationAction(WKNavigationAction, preferences: NavigationPreferences)

    // Navigation
    case didStart(URLRequest, frame: WKFrameInfo)
    case didCommit(URLRequest, frame: WKFrameInfo)

}

extension NavigationHistory {
// TODO: Check how it behaves after redirects

    var isStarted: Bool {
        self.contains { if case .didStart = $0 { return true }; return false }
    }

    var isCommitted: Bool {
        self.contains { if case .didStart = $0 { return true }; return false }
    }

    func find<T>(firstWhere condition: (Element) throws -> T?) rethrows -> T? {
        for element in self {
            if let result = try condition(element) {
                return result
            }
        }
        return nil
    }

    func find<T>(lastWhere condition: (Element) throws -> T?) rethrows -> T? {
        for element in self.reversed() {
            if let result = try condition(element) {
                return result
            }
        }
        return nil
    }

}
