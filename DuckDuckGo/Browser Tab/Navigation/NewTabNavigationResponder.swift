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

final class NewTabNavigationResponder: TabExtension {

    private weak var tab: Tab?
    var retargetedNavigation: Navigation?

    func attach(to tab: Tab) {
        self.tab = tab
    }

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> (NewWindowPolicy, retargetedNavigation: Navigation?)? {
        nil // TODO: decide and return with retargetedNavigation
    }

}

extension NewTabNavigationResponder: NavigationResponder {

    struct Dependencies {
        @Injected static var pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager
    }

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // TODO: What about form posted?
//        if navigationAction.isMiddleClick {
//            return .retarget(in: .)
//        }
//
//        let isLinkActivated = navigationAction.navigationType == .linkActivated
//        let isNavigatingAwayFromPinnedTab: Bool = {
//            let isNavigatingToAnotherDomain = navigationAction.url.host != navigationAction.sourceFrame.url?.host
//            let isPinned = tab.map(Dependencies.pinnedTabsManager.isTabPinned) ?? false
//            return isLinkActivated && isPinned && isNavigatingToAnotherDomain
//        }()
//
//        let isMiddleButtonClicked = navigationAction.isMiddleClick
//
//        // TODO: Fixthis in centralised decision maker
        // TODO: When context menu + cmd pressed: opens 2 tabs for www.duckduckgo.com link
//        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
//        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || isMiddleButtonClicked || isNavigatingAwayFromPinnedTab
//        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !isMiddleButtonClicked && !NSApp.isCommandPressed)

//        if isRequestingNewTab {
//            return .retarget(in: .tab(selected: shouldSelectNewTab))
//        }

        return .next
    }

}
