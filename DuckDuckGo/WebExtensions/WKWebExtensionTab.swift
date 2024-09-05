//
//  WKWebExtensionTab.swift
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

import Cocoa
import WebKit
import Common

extension Tab: WKWebExtensionTab {

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        return webView.window?.windowController as? MainWindowController
    }

    func indexInWindow(for context: WKWebExtensionContext) -> Int {
        let mainWindowController = webView.window?.windowController as? MainWindowController
        let mainViewController = mainWindowController?.mainViewController
        let tabCollectionViewModel = mainViewController?.tabCollectionViewModel
        let tabCollection = tabCollectionViewModel?.tabCollection
        return tabCollection?.tabs.firstIndex(of: self) ?? 0
    }

    func parentTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        return parentTab
    }

    func setParentTab(_ parentTab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        return webView
    }

    func title(for context: WKWebExtensionContext) -> String? {
        return title
    }

    func isPinned(for context: WKWebExtensionContext) -> Bool {
        return isPinned
    }

    func setPinned(_ pinned: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func isReaderModeAvailable(for context: WKWebExtensionContext) -> Bool {
        return false
    }

    func isReaderModeShowing(for context: WKWebExtensionContext) -> Bool {
        return false
    }

    func setReaderModeActive(_ readerModeShowing: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func isAudible(for context: WKWebExtensionContext) -> Bool {
        return false
    }

    func isMuted(for context: WKWebExtensionContext) -> Bool {
        return false
    }

    func setMuted(_ muted: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func size(for context: WKWebExtensionContext) -> CGSize {
        webView.frame.size
    }

    func zoomFactor(for context: WKWebExtensionContext) -> Double {
        return webView.pageZoom
    }

    func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        webView.pageZoom = zoomFactor
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        return content.urlForWebView
    }

    func pendingURL(for context: WKWebExtensionContext) -> URL? {
        return isLoading ? content.urlForWebView : nil
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        return !isLoading
    }

    func detectWebpageLocale(for context: WKWebExtensionContext, completionHandler: @escaping (Locale?, (any Error)?) -> Void) {
        completionHandler(Locale.current, nil)
    }

    func takeSnapshot(using configuration: WKSnapshotConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping (NSImage?, (any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        setContent(.url(url, credential: nil, source: .ui))
        completionHandler(nil)
    }

    func reload(fromOrigin: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        reload()
        completionHandler(nil)
    }

    func goBack(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        goBack()
        completionHandler(nil)
    }

    func goForward(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        goForward()
        completionHandler(nil)
    }

    func activate(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        let mainWindowController = webView.window?.windowController as? MainWindowController
        let mainViewController = mainWindowController?.mainViewController
        let tabCollectionViewModel = mainViewController?.tabCollectionViewModel
        return tabCollectionViewModel?.selectedTab == self
    }

    func setSelected(_ selected: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        let mainWindowController = webView.window?.windowController as? MainWindowController
        let mainViewController = mainWindowController?.mainViewController
        let tabCollectionViewModel = mainViewController?.tabCollectionViewModel
        tabCollectionViewModel?.select(tab: self)
        completionHandler(nil)
    }

    func duplicate(using configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        assertionFailure("not supported yet")
    }

    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {
        return true
    }

}
