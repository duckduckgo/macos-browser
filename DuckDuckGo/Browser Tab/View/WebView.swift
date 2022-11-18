//
//  WebView.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import os.log

final class WebView: WKWebView {

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Reopen Developer Tools when moved to another window
        if self.isInspectorShown {
            self.openDeveloperTools()
        }
    }

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Back/Forward Navigation

    var frozenCanGoBack: Bool?
    var frozenCanGoForward: Bool?

    override var canGoBack: Bool {
        frozenCanGoBack ?? super.canGoBack
    }

    override var canGoForward: Bool {
        frozenCanGoForward ?? super.canGoForward
    }

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        (navigationDelegate as? NSMenuDelegate)?.menuWillOpen?(menu)
    }

    override func didCloseMenu(_ menu: NSMenu, with event: NSEvent?) {
        super.didCloseMenu(menu, with: event)
        (navigationDelegate as? NSMenuDelegate)?.menuDidClose?(menu)
    }

}
