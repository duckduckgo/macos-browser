//
//  WKWebExtensionWindow.swift
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
import WebKit

extension MainWindowController: WKWebExtensionWindow {

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        return mainViewController.tabCollectionViewModel.tabs
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        return mainViewController.tabCollectionViewModel.selectedTab
    }

    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType {
        return .normal
    }

    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        return .normal
    }

    func setWindowState(_ state: WKWebExtension.WindowState, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func isUsingPrivateBrowsing(for context: WKWebExtensionContext) -> Bool {
        return self.mainViewController.isBurner
    }

    func screenFrame(for context: WKWebExtensionContext) -> CGRect {
        return window?.screen?.frame ?? CGRect.zero
    }

    func frame(for context: WKWebExtensionContext) -> CGRect {
        return window?.frame ?? CGRect.zero
    }

    func setFrame(_ frame: CGRect, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func focus(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

}
