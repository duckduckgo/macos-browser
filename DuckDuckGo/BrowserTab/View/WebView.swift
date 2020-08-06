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

class WebView: WKWebView {

    // MARK: - Menu

    private enum Constants {
        static let openLinkInNewTab = "Open Link in New Tab"
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        if let firstMenuItem = menu.items.first {
            switch firstMenuItem.identifier?.rawValue {
            case "WKMenuItemIdentifierOpenLink":
                editLinkMenu(menu)
            default:
                return
            }
        }
    }

    private func editLinkMenu(_ menu: NSMenu) {
        guard let newWindowMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "WKMenuItemIdentifierOpenLinkInNewWindow"}) else {
            os_log("WebView: WKMenuItemIdentifierOpenLinkInNewWindow menu item not found", log: OSLog.Category.general, type: .error)
            return
        }

        newWindowMenuItem.title = Constants.openLinkInNewTab
    }

}
