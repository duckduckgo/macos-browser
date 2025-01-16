//
//  WebExtensionManager.swift
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
import Common
import WebKit
import os.log

@available(macOS 14.4, *)
protocol WebExtensionManaging {

    // Adding and removing extensions
    var webExtensionPaths: [String] { get }
    func addExtension(path: String)
    func removeExtension(path: String)

    // Controller for tabs
    var controller: _WKWebExtensionController? { get }

    // Listening of events
    var eventsListener: WebExtensionEventsListening { get }

}

// Manages the initialization and ownership of key components: web extensions, contexts, and the controller
@available(macOS 14.4, *)
final class WebExtensionManager: NSObject, WebExtensionManaging {

    static let shared = WebExtensionManager()

    init(webExtensionPathsCache: WebExtensionPathsCaching = WebExtensionPathsCache()) {
        self.webExtensionPathsCache = webExtensionPathsCache
        super.init()

        internalSiteHandler.dataSource = self

        do {
            try loadWebExtensions()
        } catch {
            assertionFailure("Failed to load web extensions")
        }
    }

    // Caches paths to selected web extensions
    var webExtensionPathsCache: WebExtensionPathsCaching

    // Loads web extensions after selection or application start
    var loader = WebExtensionLoader()

    // Loaded extensions
    var extensions: [_WKWebExtension] = []

    // Context manages the extension's permissions and allows it to inject content, run background logic, show popovers, and display other web-based UI to the user.
    var contexts: [_WKWebExtensionContext] = []

    // Controller manages a set of loaded extension contexts
    var controller: _WKWebExtensionController?

    // Events listening
    var eventsListener: WebExtensionEventsListening = WebExtensionEventsListener()

    // Handles native messaging
    let nativeMessagingHandler = NativeMessagingHandler()

    // Handles internal sites of web extenions
    let internalSiteHandler = WebExtensionInternalSiteHandler()

    // MARK: - Adding and removing extensions
    var webExtensionPaths: [String] {
        webExtensionPathsCache.cache
    }

    func addExtension(path: String) {
        webExtensionPathsCache.add(path)
    }

    func removeExtension(path: String) {
        webExtensionPathsCache.remove(path)
    }

    // MARK: - Lifecycle

    private func loadWebExtensions() throws {
        // Load extensions
        extensions = loader.loadWebExtensions(from: webExtensionPathsCache.cache)

        // Make contexts
        contexts = extensions.map {
            makeContext(for: $0)
        }

        // Make controller and load extension contexts
        let controller = _WKWebExtensionController()
        try contexts.forEach {
            try controller.loadExtensionContext($0)
        }

        controller.delegate = self
        eventsListener.controller = controller
        self.controller = controller
    }

    private func makeContext(for webExtension: _WKWebExtension) -> _WKWebExtensionContext {
        let context = _WKWebExtensionContext(for: webExtension)

        // TODO: Temporary fix to have the same state on multiple browser sessions
        context.uniqueIdentifier = UUID(uuidString: "36dbd1f8-27c7-43fd-a206-726958a1018d")!.uuidString

        // TODO: We should consult what the extension requests to decide what to grant.
        let matchPatterns = context.webExtension.allRequestedMatchPatterns
        for pattern in matchPatterns {
            context.setPermissionStatus(.grantedExplicitly, for: pattern, expirationDate: nil)
        }

        // TODO: Grant only what the extension requests.
        let permissions: [String] = ["activeTab", "alarms", "clipboardWrite", "contextMenus", "cookies", "declarativeNetRequest", "declarativeNetRequestFeedback", "declarativeNetRequestWithHostAccess", "menus", "nativeMessaging", "notifications", "scripting", "sidePanel", "storage", "tabs", "unlimitedStorage", "webNavigation", "webRequest"]
        for permission in permissions {
            context.setPermissionStatus(.grantedExplicitly, for: permission, expirationDate: nil)
        }

        // For debugging purposes
        context.isInspectable = true
        return context
    }

    // MARK: - UI

    func toolbarButtons() -> [MouseOverButton] {
        return contexts.enumerated().map { (index, context) in
            let image = context.webExtension.icon(for: CGSize(width: 64, height: 64)) ?? NSImage(named: "Web")!
            let button = MouseOverButton(image: image, target: self, action: #selector(WebExtensionManager.toolbarButtonClicked))
            button.tag = index
            return button
        }
    }

    @MainActor
    @objc func toolbarButtonClicked(sender: NSButton) {
        let index = sender.tag
        let context = contexts[index]
        // Show dashboard - perform default action
        context.performAction(for: nil)
    }

    @MainActor
    func buttonForContext(_ context: _WKWebExtensionContext) -> NSButton? {
        guard let index = contexts.firstIndex(of: context) else {
            assertionFailure("Unknown context")
            return nil
        }

        guard let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            assertionFailure("No main window controller")
            return nil
        }

        let button = mainWindowController.mainViewController.navigationBarViewController.menuButtons.arrangedSubviews[index] as? NSButton
        return button
    }

    // MARK: - Internal

    private func setBackgroundWebViewUserAgent() {
        guard let controller else {
            assertionFailure("No controller")
            return
        }

        for context in controller.extensionContexts {
            if let backgroundWebView = context._backgroundWebView {
                if backgroundWebView.customUserAgent != UserAgent.safari {
                    backgroundWebView.customUserAgent = UserAgent.safari
                }
            }
        }
    }

}

@available(macOS 14.4, *)
@MainActor
extension WebExtensionManager: @preconcurrency _WKWebExtensionControllerDelegate {

    func webExtensionController(_ controller: _WKWebExtensionController, openWindowsFor extensionContext: _WKWebExtensionContext) -> [any _WKWebExtensionWindow] {
        var windows = WindowControllersManager.shared.mainWindowControllers
        if let focusedWindow = WindowControllersManager.shared.lastKeyMainWindowController {
            // Ensure focusedWindow is the first item
            windows.removeAll { $0 === focusedWindow }
            windows.insert(focusedWindow, at: 0)
        }
        return windows
    }

    func webExtensionController(_ controller: _WKWebExtensionController, focusedWindowFor extensionContext: _WKWebExtensionContext) -> (any _WKWebExtensionWindow)? {
        return WindowControllersManager.shared.lastKeyMainWindowController
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openNewWindowWith options: _WKWebExtensionWindowCreationOptions, for extensionContext: _WKWebExtensionContext) async throws -> (any _WKWebExtensionWindow)? {
        // Extract options
        let tabs = options.desiredURLs.map { Tab(content: .contentFromURL($0, source: .ui)) }
        let burnerMode = BurnerMode(isBurner: options.shouldUsePrivateBrowsing)
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: TabCollection(tabs: tabs),
            burnerMode: burnerMode
        )

        // Create new window
        let mainWindow = WindowControllersManager.shared.openNewWindow(
            with: tabCollectionViewModel,
            burnerMode: burnerMode,
            droppingPoint: options.desiredFrame.origin,
            contentSize: options.desiredFrame.size,
            showWindow: options.shouldFocus,
            popUp: options.desiredWindowType == .popup,
            isMiniaturized: options.desiredWindowState == .minimized,
            isMaximized: options.desiredWindowState == .maximized,
            isFullscreen: options.desiredWindowState == .fullscreen
        )

        // Move existing tabs if necessary
        try moveExistingTabs(options.desiredTabs, to: tabCollectionViewModel)

        return mainWindow?.windowController as? MainWindowController
    }

    private func moveExistingTabs(_ existingTabs: [any _WKWebExtensionTab], to targetViewModel: TabCollectionViewModel) throws {
        guard !existingTabs.isEmpty else { return }

        for existingTab in existingTabs {
            guard
                let tab = existingTab as? Tab,
                let sourceViewModel = WindowControllersManager.shared.windowController(for: tab)?
                    .mainViewController.tabCollectionViewModel,
                let currentIndex = sourceViewModel.tabCollection.tabs.firstIndex(of: tab)
            else {
                assertionFailure("Failed to find tab collection view model for \(existingTab)")
                continue
            }

            sourceViewModel.moveTab(at: currentIndex, to: targetViewModel, at: targetViewModel.tabs.count)
        }
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openNewTabWith options: _WKWebExtensionTabCreationOptions, for extensionContext: _WKWebExtensionContext) async throws -> (any _WKWebExtensionTab)? {

        if let tabCollectionViewModel = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel,
           let url = options.desiredURL {

            let content = TabContent.contentFromURL(url, source: .ui)
            let tab = Tab(content: content,
                          burnerMode: tabCollectionViewModel.burnerMode)
            tabCollectionViewModel.append(tab: tab)
            return tab
        }

        return nil
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openOptionsPageFor extensionContext: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
    }

    private func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissions permissions: Set<_WKWebExtensionPermission>, in tab: (any _WKWebExtensionTab)?, for extensionContext: _WKWebExtensionContext) async -> (Set<_WKWebExtensionPermission>, Date?) {
            return (permissions, nil)
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<_WKWebExtension.MatchPattern>, in tab: (any _WKWebExtensionTab)?, for extensionContext: _WKWebExtensionContext) async -> (Set<_WKWebExtension.MatchPattern>, Date?) {
        return (matchPatterns, nil)
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any _WKWebExtensionTab)?, for extensionContext: _WKWebExtensionContext) async -> (Set<URL>, Date?) {
        return (urls, nil)
    }

    func webExtensionController(_ controller: _WKWebExtensionController, presentPopupFor action: _WKWebExtension.Action, for context: _WKWebExtensionContext) async throws {
        guard let button = buttonForContext(context) else {
            return
        }

        guard action.presentsPopup,
              let popupPopover = action.popupPopover,
              let popupWebView = action.popupWebView
        else {
            return
        }

        popupWebView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        popupWebView.customUserAgent = UserAgent.safari

        //TODO: Temporary
        setBackgroundWebViewUserAgent()

        popupPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)

        popupWebView.reload()
    }

    func webExtensionController(_ controller: _WKWebExtensionController, sendMessage message: Any, to applicationIdentifier: String?, for extensionContext: _WKWebExtensionContext) async throws -> Any? {
        try await nativeMessagingHandler.webExtensionController(controller,
                                                                sendMessage: message,
                                                                to: applicationIdentifier,
                                                                for: extensionContext)
    }

    func webExtensionController(_ controller: _WKWebExtensionController, connectUsingMessagePort port: _WKWebExtension.MessagePort, for extensionContext: _WKWebExtensionContext) async throws {
        try await nativeMessagingHandler.webExtensionController(controller,
                                                                connectUsingMessagePort: port,
                                                                for: extensionContext)
    }

}

@available(macOS 14.4, *)
extension WebExtensionManager: WebExtensionInternalSiteHandlerDataSource {

    func webExtensionContextForUrl(_ url: URL) -> _WKWebExtensionContext? {
        guard let context = contexts.first(where: {
            return url.absoluteString.hasPrefix($0.baseURL.absoluteString)
        }) else {
            assertionFailure("No context for \(url)")
            return nil
        }

        return context
    }

}
