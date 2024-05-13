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

extension MainWindowController: _WKWebExtensionWindow {
 
    func tabs(for context: _WKWebExtensionContext) -> [_WKWebExtensionTab] {
        return mainViewController.tabCollectionViewModel.tabs
    }

    func activeTab(for context: _WKWebExtensionContext) -> _WKWebExtensionTab? {
        return mainViewController.tabCollectionViewModel.selectedTab
    }

    func windowType(for context: _WKWebExtensionContext) -> _WKWebExtensionWindowType {
        return .normal
    }

    func windowState(for context: _WKWebExtensionContext) -> _WKWebExtensionWindowState {
        return .normal
    }

    func setWindowState(_ state: _WKWebExtensionWindowState, for context: _WKWebExtensionContext) async throws {

    }

    func isUsingPrivateBrowsing(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func screenFrame(for context: _WKWebExtensionContext) -> CGRect {
        return window?.screen?.frame ?? CGRect.zero
    }

    func frame(for context: _WKWebExtensionContext) -> CGRect {
        return window?.frame ?? CGRect.zero
    }

    func setFrame(_ frame: CGRect, for context: _WKWebExtensionContext) async throws {

    }

    func focus(for context: _WKWebExtensionContext) async throws {

    }

    func close(for context: _WKWebExtensionContext) async throws {
        
    }
    
}
