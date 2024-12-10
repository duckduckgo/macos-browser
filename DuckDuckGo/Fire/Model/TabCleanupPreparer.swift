//
//  TabCleanupPreparer.swift
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
import PixelKit

protocol TabDataClearing {
    @MainActor func prepareForDataClearing(caller: TabCleanupPreparer)
}

/**
 Initiates cleanup of WebKit related data from Tabs:
 - Detach listeners and observers.
 - Flush WebView data by navigating to empty page.

 Once done, remove Tab objects.
 */
final class TabCleanupPreparer: NSObject, WKNavigationDelegate {

    private var numberOfTabs = 0
    private var processedTabs = 0

    private var completion: (() -> Void)?

    @MainActor
    func prepareTabsForCleanup(_ tabs: [TabViewModel],
                               completion: @escaping () -> Void) {
        guard !tabs.isEmpty else {
            completion()
            return
        }

        assert(self.completion == nil)
        self.completion = completion

        numberOfTabs = tabs.count
        tabs.forEach { $0.prepareForDataClearing(caller: self) }
    }

    private func notifyIfDone() {
        if processedTabs >= numberOfTabs {
            completion?()
            completion = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        processedTabs += 1

        notifyIfDone()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        PixelKit.fire(DebugEvent(GeneralPixel.blankNavigationOnBurnFailed, error: error))
        processedTabs += 1

        notifyIfDone()
    }
}
