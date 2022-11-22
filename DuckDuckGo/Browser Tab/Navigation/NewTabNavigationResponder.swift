//
//  NewTabNavigationResponder.swift
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
import Foundation

final class NewTabNavigationResponder: NavigationResponder {

    struct Dependencies {
        @Injected static var pinnedTabsManager: PinnedTabsManager = Tab.Dependencies.pinnedTabsManager
    }

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        let isLinkActivated = navigationAction.navigationType == .linkActivated
        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.request.url?.host != webView.url?.host
            let isPinned = webView.tab.map(Dependencies.pinnedTabsManager.isTabPinned) ?? false
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain
        }()

        let isMiddleButtonClicked = navigationAction.isMiddleClick

        // TODO: Fixthis in centralised decision maker
        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || isMiddleButtonClicked || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !isMiddleButtonClicked && !NSApp.isCommandPressed)

        if isRequestingNewTab {
            return .retarget(in: shouldSelectNewTab ? .selectedTab : .backgroundTab)
        }
        return .next
    }

}
