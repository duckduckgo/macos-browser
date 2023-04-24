//
//  NavigationHotkeyHandler.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Navigation

final class NavigationHotkeyHandler {

    private var onNewWindow: ((WKNavigationAction?) -> NavigationDecision)?
    private let isTabPinned: () -> Bool
    private let isBurner: Bool

    init(isTabPinned: @escaping () -> Bool, isBurner: Bool) {
        self.isTabPinned = isTabPinned
        self.isBurner = isBurner
    }

}

extension NavigationHotkeyHandler: NewWindowPolicyDecisionMaker {

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        defer {
            onNewWindow = nil
        }
        return onNewWindow?(navigationAction)
    }

}

extension NavigationHotkeyHandler: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard let targetFrame = navigationAction.targetFrame else { return .next }

        let isLinkActivated = !navigationAction.isTargetingNewWindow
            && (navigationAction.navigationType.isLinkActivated || (navigationAction.navigationType == .other && navigationAction.isUserInitiated))

        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.url.host != targetFrame.url.host && !targetFrame.url.isEmpty
            return isLinkActivated && self.isTabPinned() && isNavigatingToAnotherDomain && navigationAction.isForMainFrame
        }()

        // to be modularized later on, see https://app.asana.com/0/1201037661562251/1203487090719153/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || navigationAction.navigationType.isMiddleButtonClick || isNavigatingAwayFromPinnedTab
        if isRequestingNewTab {
            let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !navigationAction.navigationType.isMiddleButtonClick && !NSApp.isCommandPressed)
            let isBurner = isBurner

            self.onNewWindow = { _ in
                return .allow(.tab(selected: shouldSelectNewTab, burner: isBurner))
            }
            targetFrame.webView?.loadInNewWindow(navigationAction.url)
            return .cancel
        }

        return .next
    }

}

protocol NavigationHotkeyHandlerProtocol: AnyObject, NewWindowPolicyDecisionMaker, NavigationResponder {
}

extension NavigationHotkeyHandler: TabExtension, NavigationHotkeyHandlerProtocol {
    func getPublicProtocol() -> NavigationHotkeyHandlerProtocol { self }
}

extension TabExtensions {
    var navigationHotkeyHandler: NavigationHotkeyHandlerProtocol? {
        resolve(NavigationHotkeyHandler.self)
    }
}
