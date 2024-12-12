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

    func didOpenWindow(_ window: _WKWebExtensionWindow)
    func didCloseWindow(_ window: _WKWebExtensionWindow)
    func didFocusWindow(_ window: _WKWebExtensionWindow)
    func didOpenTab(_ tab: _WKWebExtensionTab)
    func didCloseTab(_ tab: _WKWebExtensionTab, windowIsClosing: Bool)
    func didActivateTab(_ tab: _WKWebExtensionTab, previousActiveTab: _WKWebExtensionTab?)
    func didSelectTabs(_ tabs: [_WKWebExtensionTab])
    func didDeselectTabs(_ tabs: [_WKWebExtensionTab])
    func didMoveTab(_ tab: _WKWebExtensionTab, from oldIndex: Int, in oldWindow: _WKWebExtensionWindow)
    func didReplaceTab(_ oldTab: _WKWebExtensionTab, with tab: _WKWebExtensionTab)
    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab: _WKWebExtensionTab)

}

// Manages web extensions and web extension context
@available(macOS 14.4, *)
final class WebExtensionManager: NSObject, WebExtensionManaging {

    static let shared = WebExtensionManager()

    static private func loadWebExtension(path: String) -> _WKWebExtension? {
        let extensionURL = URL(fileURLWithPath: path)
        let webExtension = try? _WKWebExtension(resourceBaseURL: extensionURL)
        return webExtension
    }

    static private func makeContext(for webExtension: _WKWebExtension) -> _WKWebExtensionContext {
        let context = _WKWebExtensionContext(for: webExtension)

        // TODO: Temporary fix to have the same state on multiple browser sessions
        context.uniqueIdentifier = UUID(uuidString: "36dbd1f8-27c7-43fd-a206-726958a1018d")!.uuidString

        // TODO: We should consult what the extension requests to decide what to grant.
        let matchPatterns = context.webExtension.allRequestedMatchPatterns
        for pattern in matchPatterns {
            context.setPermissionStatus(.grantedExplicitly, for: pattern, expirationDate: nil)
        }

        // TODO: Grant only what the extension requests.
        let permissions: [_WKWebExtension.Permission] = [.activeTab, .alarms, .clipboardWrite, .contextMenus, .cookies, .declarativeNetRequest, .declarativeNetRequestFeedback, .declarativeNetRequestWithHostAccess, .menus, .nativeMessaging, .scripting, .storage, .tabs, .unlimitedStorage, .webNavigation, .webRequest]
        for permission in permissions {
            context.setPermissionStatus(.grantedExplicitly, for: permission, expirationDate: nil)
        }

        // For debugging purposes
        context.isInspectable = true
        return context
    }

    lazy var extensions: [_WKWebExtension] = {
        guard let nativeMessaging = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "add-on", ofType: nil)!) else {
            return []
        }

//        let bitwarden = WebExtensionManager.loadWebExtension(path: "/Applications/Bitwarden.app/Contents/PlugIns/safari.appex/Contents/Resources/")
//        let lastpass = WebExtensionManager.loadWebExtension(path: "/Applications/LastPass.app/Contents/PlugIns/safariext.appex/Contents/Resources/")
//        let lastpassForSafari = WebExtensionManager.loadWebExtension(path: "/Applications/LastPass for Safari.app/Contents/PlugIns/LastPass for Safari Extension.appex/Contents/Resources/")
//        let dashlane = WebExtensionManager.loadWebExtension(path: "/Applications/Dashlane.app/Contents/PlugIns/SafariWebExtension (macOS).appex/Contents/Resources/")
//        let nordpass = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let onePassword = WebExtensionManager.loadWebExtension(path: "/Applications/1Password for Safari.app/Contents/PlugIns/1Password.appex/Contents/Resources/")
//        let okta = WebExtensionManager.loadWebExtension(path: "/Applications/Okta Extension App.app/Contents/PlugIns/WebExtension.appex/Contents/Resources")
//        let adBlock = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let nightEye = WebExtensionManager.loadWebExtension(path: "/Applications/Night Eye.app/Contents/PlugIns/Night Eye Extension.appex/Contents/Resources/")

        return [nativeMessaging]
    }()

    // Context manages the extension's permissions and allows it to inject content, run background logic, show popovers, and display other web-based UI to the user.
    lazy var contexts: [_WKWebExtensionContext] = {
        return extensions.map {
            WebExtensionManager.makeContext(for: $0)
        }
    }()

    lazy var extensionController = {
        let controller = _WKWebExtensionController()

        contexts.forEach {
            do {
                try controller.loadExtensionContext($0)
            } catch {
                fatalError("Didn't load extension")
            }
        }

        controller.delegate = self
        return controller
    }()

    let nativeMessagingHandler = NativeMessagingHandler()

    func setUpWebExtensionController(for configuration: WKWebViewConfiguration) {
        configuration._webExtensionController = extensionController
    }

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

        // Uncomment the line below to enable debugging of the background script
        showBackgroundConsole(context: context)
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

    func setBackgroundWebViewUserAgent() {
        for context in extensionController.extensionContexts {
            if let backgroundWebView = context._backgroundWebView {
                if backgroundWebView.customUserAgent != UserAgent.safari {
                    backgroundWebView.customUserAgent = UserAgent.safari
                }
            }
        }
    }

    @MainActor
    func showBackgroundConsole(context: _WKWebExtensionContext) {
        guard let backgroundWebView = context._backgroundWebView else {
            return
        }
        backgroundWebView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        guard backgroundWebView.responds(to: NSSelectorFromString("_inspector")),
              let inspector = backgroundWebView.value(forKey: "_inspector") as? NSObject,
              inspector.responds(to: NSSelectorFromString("showConsole")) else {
            assertionFailure("_WKInspector does not respond to show")
            return
        }

        inspector.perform(NSSelectorFromString("showConsole"), with: nil)
    }

    // MARK: - Context

    func didOpenWindow(_ window: _WKWebExtensionWindow) {
        extensionController.didOpen(window)
    }

    func didCloseWindow(_ window: _WKWebExtensionWindow) {
        extensionController.didClose(window)
    }

    func didFocusWindow(_ window: _WKWebExtensionWindow) {
        extensionController.didFocus(window)
    }

    func didOpenTab(_ tab: _WKWebExtensionTab) {
        extensionController.didOpen(tab)
    }

    func didCloseTab(_ tab: _WKWebExtensionTab, windowIsClosing: Bool) {
        extensionController.didClose(tab, windowIsClosing: windowIsClosing)
    }

    func didActivateTab(_ tab: _WKWebExtensionTab, previousActiveTab: _WKWebExtensionTab?) {
        extensionController.didActivate(tab, previousActiveTab: previousActiveTab)
    }

    func didSelectTabs(_ tabs: [_WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        extensionController.didSelect(set)
    }

    func didDeselectTabs(_ tabs: [_WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        extensionController.didDeselect(set)
    }

    func didMoveTab(_ tab: _WKWebExtensionTab, from oldIndex: Int, in oldWindow: _WKWebExtensionWindow) {
        extensionController.didMoveTab(tab, from: UInt(oldIndex), in: oldWindow)
    }

    func didReplaceTab(_ oldTab: _WKWebExtensionTab, with tab: _WKWebExtensionTab) {
        extensionController.didReplaceTab(oldTab, with: tab)
    }

    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab: _WKWebExtensionTab) {
        extensionController.didChangeTabProperties(properties, for: tab)
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
            let configuration = url.isWebExtensionUrl ? extensionContext.webViewConfiguration : nil
            let tab = Tab(content: .url(url, source: .ui),
                          webViewConfiguration: configuration,
                          burnerMode: tabCollectionViewModel.burnerMode)
            tabCollectionViewModel.append(tab: tab)
            return tab
        }

        return nil
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openOptionsPageFor extensionContext: _WKWebExtensionContext) async throws {
        assertionFailure("not supported yet")
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissions permissions: Set<_WKWebExtension.Permission>, in tab: (any _WKWebExtensionTab)?, for extensionContext: _WKWebExtensionContext) async -> (Set<_WKWebExtension.Permission>, Date?) {
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
