//
//  Tab+Navigation.swift
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
import Common
import Foundation
import WebKit

extension Tab: NavigationResponder {

    // "protected" navigationDelegate
    private var navigationDelegate: DistributedNavigationDelegate! {
        self.value(forKey: Tab.objcNavigationDelegateKeyPath) as? DistributedNavigationDelegate
    }

    // "protected" newWindowPolicyDecisionMakers
    private var newWindowPolicyDecisionMakers: [NewWindowPolicyDecisionMaker]? {
        get {
            self.value(forKey: Tab.objcNewWindowPolicyDecisionMakersKeyPath) as? [NewWindowPolicyDecisionMaker]
        }
        set {
            self.setValue(newValue, forKey: Tab.objcNewWindowPolicyDecisionMakersKeyPath)
        }
    }

    func setupNavigationDelegate() {
        navigationDelegate.setResponders(
            .weak(nullable: self.navigationHotkeyHandler),

            // redirect to SERP for non-valid domains entered by user
            // should be before `self` to avoid Tab presenting an error screen
            .weak(nullable: self.searchForNonexistentDomains),

            .weak(self),

            // Duck Player overlay navigations handling
            .weak(nullable: self.duckPlayer),

            // open external scheme link in another app
            .weak(nullable: self.externalAppSchemeHandler),

            // tracking link rewrite, referrer trimming, global privacy control
            .weak(nullable: self.navigationProtection),

            .weak(nullable: self.downloads),

            .weak(nullable: self.adClickAttribution),

            // update blocked trackers info
            .weak(nullable: self.privacyDashboard),
            // upgrade to HTTPS
            .weak(nullable: self.httpsUpgrade),

            // add extra headers to SERP requests
            .struct(SerpHeadersNavigationResponder()),

            // ensure Content Blocking Rules are applied before navigation
            .weak(nullable: self.contentBlockingAndSurrogates),
            // update click-to-load state
            .weak(nullable: self.fbProtection),
            // browsing history
            .weak(nullable: self.history),

            // Find In Page
            .weak(nullable: self.findInPage),

            // Tab Snapshots
            .weak(nullable: self.tabSnapshots),

            // should be the last, for Unit Tests navigation events tracking
            .struct(nullable: testsClosureNavigationResponder)
        )

        newWindowPolicyDecisionMakers = [NewWindowPolicyDecisionMaker?](arrayLiteral:
            self.contextMenuManager,
            self.navigationHotkeyHandler,
            self.duckPlayer
        ).compactMap { $0 }

        if let downloadsExtension = self.downloads {
            navigationDelegate
                .registerCustomDelegateMethodHandler(.weak(downloadsExtension), forSelectorNamed: "_webView:contextMenuDidCreateDownload:")
        }
    }

}
