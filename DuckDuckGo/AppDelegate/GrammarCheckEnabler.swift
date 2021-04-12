//
//  GrammarCheckEnabler.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class GrammarCheckEnabler {

    private var windowControllersManager: WindowControllersManager

    // Please see WebKit/UIProcess/Cocoa/WebViewImpl.mm
    private let spellingCheckFakeMenuItem = NSMenuItem(action: #selector(NSTextView.toggleContinuousSpellChecking(_:)))
    private let grammarCheckFakeMenuItem = NSMenuItem(action: #selector(NSTextView.toggleGrammarChecking(_:)))

    init(windowControllersManager: WindowControllersManager) {
        self.windowControllersManager = windowControllersManager
    }

    @UserDefaultsWrapper(key: .spellingCheckEnabledOnce, defaultValue: false)
    var spellingCheckEnabledOnce: Bool

    @UserDefaultsWrapper(key: .grammarCheckEnabledOnce, defaultValue: false)
    var grammarCheckEnabledOnce: Bool

    func enableIfNeeded() {

        func enableCheckIfNeeded(representedBy menuItem: NSMenuItem, onceEnabled: inout Bool, webView: WebView) {
            guard !onceEnabled else {
                return
            }

            // WKWebView doesn't have an API to read/set grammar checks
            // Workaround is to provide a fake menu item that webview changes based on the current setting
            webView.validateUserInterfaceItem(menuItem)
            // If the setting is off, toggle it
            if menuItem.state == .off {
                webView.perform(menuItem.action)
                onceEnabled = true
            }
        }

        guard let webView = windowControllersManager.firstWebView else {
            assertionFailure("GrammarCheckEnabler: Failed to get web view")
            return
        }

        enableCheckIfNeeded(representedBy: spellingCheckFakeMenuItem, onceEnabled: &spellingCheckEnabledOnce, webView: webView)
        enableCheckIfNeeded(representedBy: grammarCheckFakeMenuItem, onceEnabled: &grammarCheckEnabledOnce, webView: webView)
    }

}

fileprivate extension WindowControllersManager {

    var firstWebView: WebView? {
        return mainWindowControllers
            .compactMap { $0.mainViewController.tabCollectionViewModel.tabCollection.tabs.first?.webView }
            .first
    }

}
