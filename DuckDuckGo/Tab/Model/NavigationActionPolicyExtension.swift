//
//  NavigationActionPolicyExtension.swift
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

import Navigation

extension NavigationActionPolicy {

    /// cancel+redirect Navigation Action popping last WebView Back Item
    /// if a client-redirected navigation has been committed its BackForwardItem will stay in history
    /// when the Navigation Action is cancelled in decidePolicyForNavigationAction:
    /// https://app.asana.com/0/inbox/1199237043628108/1201280322539473/1201353436736961
    @MainActor
    static func redirectInvalidatingBackItemIfNeeded(_ navigationAction: NavigationAction, do redirect: @escaping (Navigator) -> Void) -> NavigationActionPolicy {
        guard let mainFrame = navigationAction.mainFrameTarget,
              let webView = navigationAction.targetFrame?.webView else {
            assertionFailure("Trying to redirect non-main-frame NavigationAction")
            return .cancel
        }
        return .redirect(mainFrame) { navigator in
            // Cancelled & Upgraded Client Redirect URL leaves wrong backForwardList record

            if case .redirect(.client(delay: 0)) = navigationAction.navigationType {
                // initial NavigationAction BackForwardListItem is not the Current Item (new item was pushed during navigation)
                if let fromHistoryItemIdentity = navigationAction.redirectHistory?.last?.fromHistoryItemIdentity,
                   fromHistoryItemIdentity != webView.backForwardList.currentItem?.identity {

                    navigator.goBack()?.overrideResponders { _, _ in
                        // don‘t perform actual navigation, just pop the back item
                        .cancel
                    }

                // we can‘t go back when navigating from an empty state
                } else if !webView.canGoBack {
                    // use the private call to clear navigation history
                    webView.backForwardList.removeAllItems()

                }
            }

            redirect(navigator)
        }
    }

}
