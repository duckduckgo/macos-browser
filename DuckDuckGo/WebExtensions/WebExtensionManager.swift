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

protocol WebExtensionManaging {

    func didOpenWindow(_ window: WKWebExtensionWindow)
    func didCloseWindow(_ window: WKWebExtensionWindow)
    func didFocusWindow(_ window: WKWebExtensionWindow)
    func didOpenTab(_ tab: WKWebExtensionTab)
    func didCloseTab(_ tab: WKWebExtensionTab, windowIsClosing: Bool)
    func didActivateTab(_ tab: WKWebExtensionTab, previousActiveTab: WKWebExtensionTab?)
    func didSelectTabs(_ tabs: [WKWebExtensionTab])
    func didDeselectTabs(_ tabs: [WKWebExtensionTab])
    func didMoveTab(_ tab: WKWebExtensionTab, from oldIndex: Int, in oldWindow: WKWebExtensionWindow)
    func didReplaceTab(_ oldTab: WKWebExtensionTab, with tab: WKWebExtensionTab)
    func didChangeTabProperties(_ properties: WKWebExtension.TabChangedProperties, for tab: WKWebExtensionTab)

}

// Manages web extensions and web extension context
@available(macOS 13.1, *)
final class WebExtensionManager: NSObject, WebExtensionManaging {

    static let shared = WebExtensionManager()

    static private func loadWebExtension(path: String) -> _WKWebExtension? {
        let extensionURL = URL(fileURLWithPath: path)
        let webExtension = try? _WKWebExtension(resourceBaseURL: extensionURL)
        return webExtension
    }

    // swiftlint:disable force_try
    static private func makeContext(for webExtension: _WKWebExtension) -> WKWebExtensionContext {
        let context = WKWebExtensionContext(for: webExtension)
        context.uniqueIdentifier = UUID().uuidString
        let matchPattern = try! _WKWebExtension.MatchPattern(string: "*://*/*")
        context.setPermissionStatus(.grantedExplicitly, for: matchPattern, expirationDate: nil)

        // Grant all requested API permissions.
        let permissions: [WKWebExtension.Permission] = [.activeTab, .alarms, .clipboardWrite, .contextMenus, .cookies, .declarativeNetRequest, .declarativeNetRequestFeedback, .declarativeNetRequestWithHostAccess, .menus, .nativeMessaging, .scripting, .storage, .tabs, .unlimitedStorage, .webNavigation, .webRequest]
        for permission in permissions {
            context.setPermissionStatus(.grantedExplicitly, for: WKWebExtension.Permission.activeTab, expirationDate: nil)
        }

        // For debugging purposes
        context.isInspectable = true
        return context
    }
    // swiftlint:disable force_try

    lazy var extensions: [_WKWebExtension] = {
        guard let loadedExtension = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "dnr-block-dynamic", ofType: nil)!) else {
            return []
        }

        return [loadedExtension]
    }()

    // Context manages the extension's permissions and allows it to inject content, run background logic, show popovers, and display other web-based UI to the user.
    lazy var contexts: [WKWebExtensionContext] = {
        return extensions.map {
            WebExtensionManager.makeContext(for: $0)
        }
    }()

    lazy var extensionController = {
        let controller = WKWebExtensionController()

        contexts.forEach {
            do {
                try controller.load($0)
            } catch {
                fatalError("Didn't load extension")
            }
        }

        controller.delegate = self
        return controller
    }()

    func setUpWebExtensionController(for configuration: WKWebViewConfiguration) {
        configuration._setWebExtensionController(extensionController)
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

        showBackgroundConsole(context: context)
    }

    @MainActor
    func buttonForContext(_ context: WKWebExtensionContext) -> NSButton? {
        guard let index = contexts.firstIndex(of: context) else {
            assertionFailure("Unknown context")
            return nil
        }

        guard let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            assertionFailure("No main window controller")
            return nil
        }

        let button = mainWindowController.mainViewController.navigationBarViewController.rightButtons.arrangedSubviews[index] as? NSButton
        return button
    }

    @MainActor
    private func showPopover(popupWebView: WKWebView, button: NSButton) {
        popupWebView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let popover = NSPopover()
        popover.behavior = .applicationDefined
        let viewController = NSViewController()
        viewController.view.addSubview(popupWebView)
        popupWebView.translatesAutoresizingMaskIntoConstraints = false
        popupWebView.topAnchor.constraint(equalTo: viewController.view.topAnchor, constant: 0).isActive = true
        popupWebView.leftAnchor.constraint(equalTo: viewController.view.leftAnchor, constant: 0).isActive = true
        popupWebView.rightAnchor.constraint(equalTo: viewController.view.rightAnchor, constant: 0).isActive = true
        popupWebView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor, constant: 0).isActive = true
        popover.contentViewController = viewController
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    @MainActor
    func showBackgroundConsole(context: WKWebExtensionContext) {
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

    func didOpenWindow(_ window: WKWebExtensionWindow) {
        extensionController.didOpenWindow(window)
    }

    func didCloseWindow(_ window: WKWebExtensionWindow) {
        extensionController.didCloseWindow(window)
    }

    func didFocusWindow(_ window: WKWebExtensionWindow) {
        extensionController.didFocusWindow(window)
    }

    func didOpenTab(_ tab: WKWebExtensionTab) {
        extensionController.didOpenTab(tab)
    }

    func didCloseTab(_ tab: WKWebExtensionTab, windowIsClosing: Bool) {
        extensionController.didCloseTab(tab, windowIsClosing: windowIsClosing)
    }

    func didActivateTab(_ tab: WKWebExtensionTab, previousActiveTab: WKWebExtensionTab?) {
        extensionController.didActivateTab(tab, previousActiveTab: previousActiveTab)
    }

    func didSelectTabs(_ tabs: [WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        extensionController.didSelectTabs(set)
    }

    func didDeselectTabs(_ tabs: [WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        extensionController.didDeselectTabs(set)
    }

    func didMoveTab(_ tab: WKWebExtensionTab, from oldIndex: Int, in oldWindow: WKWebExtensionWindow) {
        extensionController.didMoveTab(tab, from: oldIndex, in: oldWindow)
    }

    func didReplaceTab(_ oldTab: WKWebExtensionTab, with tab: WKWebExtensionTab) {
        extensionController.didReplaceTab(oldTab, with: tab)
    }

    func didChangeTabProperties(_ properties: WKWebExtension.TabChangedProperties, for tab: WKWebExtensionTab) {
        extensionController.didChangeTabProperties(properties, for: tab)
    }

}

@available(macOS 13.1, *)
extension WebExtensionManager: WKWebExtensionControllerDelegate {

    public func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        return []
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        return WindowControllersManager.shared.lastKeyMainWindowController
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration, for extensionContext: WKWebExtensionContext) async throws -> (any WKWebExtensionWindow)? {
        return nil
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for extensionContext: WKWebExtensionContext) async throws -> (any WKWebExtensionTab)? {
        if let url = configuration.url {
            let tab = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController.openNewTab(with: .url(url, source: .ui))
            return tab
        }

        return nil
    }

    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext) async throws {

    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.Permission>, Date?) {
        return (Set(), nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<URL>, Date?) {
        return (Set(), nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.MatchPattern>, Date?) {
        return (Set(), nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext) async throws {
        guard let button = buttonForContext(context) else {
            return
        }

        guard action.presentsPopup, let popupWebView = action.popupWebView else {
            return
        }

        showPopover(popupWebView: popupWebView, button: button)
    }

    func webExtensionController(_ controller: WKWebExtensionController, sendMessage message: Any, toApplicationWithIdentifier applicationIdentifier: String?, for extensionContext: WKWebExtensionContext) async throws -> Any? {
        return nil
    }

    func webExtensionController(_ controller: WKWebExtensionController, connectUsing port: WKWebExtension.MessagePort, for extensionContext: WKWebExtensionContext) async throws {

    }

}
