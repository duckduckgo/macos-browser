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
    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab:_WKWebExtensionTab)

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
    static private func makeContext(for webExtension: _WKWebExtension) -> _WKWebExtensionContext {
        let context = _WKWebExtensionContext(for: webExtension)
        context.uniqueIdentifier = UUID().uuidString
        let matchPattern = try! _WKWebExtension.MatchPattern(string: "*://*/*")
        context.setPermissionStatus(.grantedExplicitly, for: matchPattern, expirationDate: nil)
        //For debugging purposes
        context.isInspectable = true
        return context
    }
    // swiftlint:disable force_try

    lazy var extensions: [_WKWebExtension] = {
        // Bundled extensions
        let emoji = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "emoji-substitution", ofType: nil)!)
//        let openMyPageButton = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "open-my-page-button", ofType: nil)!)
//        let tabs = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "tabs-tabs-tabs", ofType: nil)!)
//        let urlBlocker = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "url-blocker", ofType: nil)!)

        // Popular extensions
//        let bitwarden = WebExtensionManager.loadWebExtension(path: "/Applications/Bitwarden.app/Contents/PlugIns/safari.appex/Contents/Resources/")
//        let lastpass = WebExtensionManager.loadWebExtension(path: "/Applications/LastPass.app/Contents/PlugIns/safariext.appex/Contents/Resources/")
//        let dashlane = WebExtensionManager.loadWebExtension(path: "/Applications/Dashlane.app/Contents/PlugIns/SafariWebExtension (macOS).appex/Contents/Resources/")
//        let nordpass = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let adBlock = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let nightEye = WebExtensionManager.loadWebExtension(path: "/Applications/Night Eye.app/Contents/PlugIns/Night Eye Extension.appex/Contents/Resources/")

//        return [bitwarden!]
        return [emoji!]
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

        // For debug purposes
        // Show background script console
//        showBackgroundConsole(context: context)
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

        // !TODO UNCOMMENT
        let button = mainWindowController.mainViewController.navigationBarViewController.rightButtons.arrangedSubviews[index] as? NSButton
        return button
//        return nil
    }

    @MainActor
    private func showPopover(popupWebView: WKWebView, button: NSButton) {
        popupWebView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let popover = NSPopover()
        popover.behavior = .semitransient
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
    func showBackgroundConsole(context: _WKWebExtensionContext) {
        guard let backgroundWebView = context._backgroundWebView else {
            return
        }
        backgroundWebView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        guard let button = buttonForContext(context) else {
            return
        }

        showPopover(popupWebView: backgroundWebView, button: button)

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
//        extensionController.didSelect(NSSet(array: tabs))
    }

    func didDeselectTabs(_ tabs: [_WKWebExtensionTab]) {
//        extensionController.didDeselect(NSSet(array: tabs))
    }

    func didMoveTab(_ tab: _WKWebExtensionTab, from oldIndex: Int, in oldWindow: _WKWebExtensionWindow) {
        extensionController.didMoveTab(tab, from: oldIndex, in: oldWindow)
    }

    func didReplaceTab(_ oldTab: _WKWebExtensionTab, with tab: _WKWebExtensionTab) {
        extensionController.didReplaceTab(oldTab, with: tab)
    }

    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab: _WKWebExtensionTab) {
        extensionController.didChangeTabProperties(properties, for: tab)
    }

}

@available(macOS 13.1, *)
extension WebExtensionManager: _WKWebExtensionControllerDelegate {

    func webExtensionController(_ controller: _WKWebExtensionController, openWindowsFor extensionContext: _WKWebExtensionContext) -> [_WKWebExtensionWindow] {
        os_log(.error, log: .extensions, "Open window for")
        return []
    }

    func webExtensionController(_ controller: _WKWebExtensionController, focusedWindowFor extensionContext: _WKWebExtensionContext) -> _WKWebExtensionWindow? {
        os_log(.error, log: .extensions, "Focused window for")
        return nil
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openNewWindowWith options: _WKWebExtensionWindowCreationOptions, for extensionContext: _WKWebExtensionContext) async throws -> _WKWebExtensionWindow? {
        os_log(.error, log: .extensions, "Open new window with")
        return nil
    }

    func webExtensionController(_ controller: _WKWebExtensionController, openOptionsPageFor extensionContext: _WKWebExtensionContext) async throws {
        os_log(.error, log: .extensions, "Open options page for")
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissions permissions: Set<_WKWebExtension.Permission>, in tab: _WKWebExtensionTab?, for extensionContext: _WKWebExtensionContext) async -> Set<_WKWebExtension.Permission> {
        os_log(.error, log: .extensions, "Open options page for")
        return Set()
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<_WKWebExtension.MatchPattern>, in tab: _WKWebExtensionTab?, for extensionContext: _WKWebExtensionContext) async -> Set<_WKWebExtension.MatchPattern> {
        os_log(.error, log: .extensions, "Prompt for permission match patterns")
        return Set()
    }

    func webExtensionController(_ controller: _WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: _WKWebExtensionTab?, for extensionContext: _WKWebExtensionContext) async -> Set<URL> {
        os_log(.error, log: .extensions, "Prompt for permission match patterns")
        return Set()
    }

    func webExtensionController(_ controller: _WKWebExtensionController, sendMessage message: Any, to applicationIdentifier: String?, for extensionContext: _WKWebExtensionContext) async throws -> Any? {
        return message
    }

    func webExtensionController(_ controller: _WKWebExtensionController, connectUsingMessagePort port: _WKWebExtension.MessagePort, for extensionContext: _WKWebExtensionContext) async throws {

    }

    func webExtensionController(_ controller: _WKWebExtensionController, presentPopupFor action: _WKWebExtension.Action, for context: _WKWebExtensionContext) async throws {
        guard let button = await buttonForContext(context) else {
            return
        }
        guard action.presentsPopup, let popupWebView = action.popupWebView else {
            return
        }

        await showPopover(popupWebView: popupWebView, button: button)
    }

}
