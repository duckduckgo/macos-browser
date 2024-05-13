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

import Foundation
import WebKit

extension Tab: _WKWebExtensionTab {

    @MainActor func window(for context: _WKWebExtensionContext) -> _WKWebExtensionWindow? {
        return webView.window?.windowController as? MainWindowController
    }

    func parentTab(for context: _WKWebExtensionContext) -> _WKWebExtensionTab? {
        return parentTab
    }

    func setParent(_ parentTab: _WKWebExtensionTab?, for context: _WKWebExtensionContext) async throws {
        
    }

    func mainWebView(for context: _WKWebExtensionContext) -> WKWebView? {
        return webView
    }

    func webViews(for context: _WKWebExtensionContext) -> [WKWebView] {
        return [webView]
    }

    func tabTitle(for context: _WKWebExtensionContext) -> String? {
        return title
    }

    func isPinned(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func pin(for context: _WKWebExtensionContext) async throws {

    }

    func unpin(for context: _WKWebExtensionContext) async throws {

    }

    func isReaderModeAvailable(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func isShowingReaderMode(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func toggleReaderMode(for context: _WKWebExtensionContext) async throws {
        
    }

    func isAudible(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func isMuted(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func mute(for context: _WKWebExtensionContext) async throws {

    }

    func unmute(for context: _WKWebExtensionContext) async throws {

    }

    func size(for context: _WKWebExtensionContext) -> CGSize {
        return webView.frame.size
    }

    func zoomFactor(for context: _WKWebExtensionContext) -> Double {
        return webView.pageZoom
    }

    @MainActor func setZoomFactor(_ zoomFactor: Double, for context: _WKWebExtensionContext) async throws {
        webView.pageZoom = zoomFactor
    }

    func url(for context: _WKWebExtensionContext) -> URL? {
        return content.urlForWebView
    }

    func pendingURL(for context: _WKWebExtensionContext) -> URL? {
        return content.urlForWebView
    }

    func isLoadingComplete(for context: _WKWebExtensionContext) -> Bool {
        return !isLoading
    }

    func detectWebpageLocale(for context: _WKWebExtensionContext) async throws -> Locale? {
        return nil
    }

    @MainActor func load(_ url: URL, for context: _WKWebExtensionContext) async throws {
        setContent(.url(url, credential: nil, source: .bookmark))
    }

    @MainActor func reload(for context: _WKWebExtensionContext) async throws {
        reload()
    }

    func reloadFromOrigin(for context: _WKWebExtensionContext) async throws {

    }

    @MainActor func goBack(for context: _WKWebExtensionContext) async throws {
        goBack()
    }

    @MainActor func goForward(for context: _WKWebExtensionContext) async throws {
        goForward()
    }

    func activate(for context: _WKWebExtensionContext) async throws {
        
    }

    func isSelected(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func select(for context: _WKWebExtensionContext) async throws {

    }

    func deselect(for context: _WKWebExtensionContext) async throws {

    }

    func duplicate(for context: _WKWebExtensionContext, with options: _WKWebExtensionTabCreationOptions) async throws -> _WKWebExtensionTab? {
        return nil
    }

    func close(for context: _WKWebExtensionContext) async throws {

    }
}
