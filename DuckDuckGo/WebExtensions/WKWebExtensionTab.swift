//
//  WKWebExtensionTab.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

@available(macOS 14.4, *)
@MainActor
extension Tab: @preconcurrency _WKWebExtensionTab {

    enum WebExtensionTabError: Error {
        case notSupported
        case tabNotFound
        case alreadyPinned
        case notPinned
        case alreadyMuted
        case notMuted
    }

    private var tabCollectionViewModel: TabCollectionViewModel? {
        let mainWindowController = WindowControllersManager.shared.windowController(for: self)
        let mainViewController = mainWindowController?.mainViewController
        return mainViewController?.tabCollectionViewModel
    }

    func window(for context: _WKWebExtensionContext) -> (any _WKWebExtensionWindow)? {
        return webView.window?.windowController as? MainWindowController
    }

    @MainActor
    func indexInWindow(for context: _WKWebExtensionContext) -> UInt {
        let tabCollection = tabCollectionViewModel?.tabCollection
        return UInt(tabCollection?.tabs.firstIndex(of: self) ?? 0)
    }

    func parentTab(for context: _WKWebExtensionContext) -> (any _WKWebExtensionTab)? {
        return parentTab
    }

    func setParent(_ parentTab: (any _WKWebExtensionTab)?, for context: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
        throw WebExtensionTabError.notSupported
    }

    func mainWebView(for context: _WKWebExtensionContext) -> WKWebView? {
        return webView
    }

    func tabTitle(for context: _WKWebExtensionContext) -> String? {
        return title
    }

    func isPinned(for context: _WKWebExtensionContext) -> Bool {
        return isPinned
    }

    func pin(for context: _WKWebExtensionContext) async throws {
        guard let tabIndex = tabCollectionViewModel?.indexInAllTabs(of: self) else {
            assertionFailure("Tab not found")
            throw WebExtensionTabError.tabNotFound
        }

        switch tabIndex {
        case .pinned:
            assertionFailure("Tab is already pinned")
            throw WebExtensionTabError.alreadyPinned
        case .unpinned(let index):
            tabCollectionViewModel?.pinTab(at: index)
        }
    }

    func unpin(for context: _WKWebExtensionContext) async throws {
        guard let tabIndex = tabCollectionViewModel?.indexInAllTabs(of: self) else {
            assertionFailure("Tab not found")
            throw WebExtensionTabError.tabNotFound
        }

        switch tabIndex {
        case .pinned(let index):
            tabCollectionViewModel?.unpinTab(at: index)
        case .unpinned:
            assertionFailure("Tab is not pinned")
            throw WebExtensionTabError.notPinned
        }
    }

    func isReaderModeAvailable(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func isShowingReaderMode(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func toggleReaderMode(for context: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
        throw WebExtensionTabError.notSupported
    }

    func isAudible(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func isMuted(for context: _WKWebExtensionContext) -> Bool {
        return false
    }

    func mute(for context: _WKWebExtensionContext) async throws {
        guard audioState.isMuted else {
            assertionFailure("Tab is muted")
            throw WebExtensionTabError.alreadyMuted
        }

        muteUnmuteTab()
    }

    func unmute(for context: _WKWebExtensionContext) async throws {
        guard !audioState.isMuted else {
            assertionFailure("Tab is not muted")
            throw WebExtensionTabError.notMuted
        }

        muteUnmuteTab()
    }

    func size(for context: _WKWebExtensionContext) -> CGSize {
        webView.frame.size
    }

    func zoomFactor(for context: _WKWebExtensionContext) -> Double {
        return webView.pageZoom
    }

    func setZoomFactor(_ zoomFactor: Double, for context: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
    }

    func url(for context: _WKWebExtensionContext) -> URL? {
        return content.urlForWebView
    }

    func pendingURL(for context: _WKWebExtensionContext) -> URL? {
        return isLoading ? content.urlForWebView : nil
    }

    func isLoadingComplete(for context: _WKWebExtensionContext) -> Bool {
        return !isLoading
    }

    func detectWebpageLocale(for context: _WKWebExtensionContext) async throws -> Locale? {
        return Locale.current
    }

    func captureVisibleWebpage(for context: _WKWebExtensionContext) async throws -> NSImage? {
        assertionFailure("not supported yet")
        throw WebExtensionTabError.notSupported
    }

    func load(_ url: URL, for context: _WKWebExtensionContext) async throws {
        setContent(.url(url, credential: nil, source: .ui))
    }

    func reload(for context: _WKWebExtensionContext) async throws {
        reload()
    }

    func reloadFromOrigin(for context: _WKWebExtensionContext) async throws {
        reload()
    }

    func goBack(for context: _WKWebExtensionContext) async throws {
        goBack()
    }

    func goForward(for context: _WKWebExtensionContext) async throws {
        goForward()
    }

    func activate(for context: _WKWebExtensionContext) async throws {
        tabCollectionViewModel?.select(tab: self)
    }

    @MainActor
    func isSelected(for context: _WKWebExtensionContext) -> Bool {
        return tabCollectionViewModel?.selectedTab == self
    }

    func select(for context: _WKWebExtensionContext) async throws {
        tabCollectionViewModel?.select(tab: self)
    }

    func deselect(for context: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
        throw WebExtensionTabError.notSupported
    }

    func duplicate(for context: _WKWebExtensionContext, with options: _WKWebExtensionTabCreationOptions) async throws -> (any _WKWebExtensionTab)? {
        assertionFailure("not supported yet")
        throw WebExtensionTabError.notSupported
    }

    func close(for context: _WKWebExtensionContext) async throws {
        if let index = tabCollectionViewModel?.indexInAllTabs(of: self) {
            tabCollectionViewModel?.remove(at: index)
        } else {
            throw WebExtensionTabError.tabNotFound
        }
    }

    func shouldGrantTabPermissionsOnUserGesture(for context: _WKWebExtensionContext) -> Bool {
        return true
    }

}
