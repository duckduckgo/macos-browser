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
        //For debugging purposes
        context.isInspectable = true
        return context
    }
    // swiftlint:disable force_try

    lazy var extensions: [_WKWebExtension] = {
        // Bundled extensions
//        let emoji = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "emoji-substitution", ofType: nil)!)
//        let notifyLink = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "notify-link-clicks-i18n", ofType: nil)!)
        let cookieBgPicker = WebExtensionManager.loadWebExtension(path: Bundle.main.path(forResource: "cookie-bg-picker", ofType: nil)!)

        // Popular extensions
//        let bitwarden = WebExtensionManager.loadWebExtension(path: "/Applications/Bitwarden.app/Contents/PlugIns/safari.appex/Contents/Resources/")
//        let lastpass = WebExtensionManager.loadWebExtension(path: "/Applications/LastPass.app/Contents/PlugIns/safariext.appex/Contents/Resources/")
//        let dashlane = WebExtensionManager.loadWebExtension(path: "/Applications/Dashlane.app/Contents/PlugIns/SafariWebExtension (macOS).appex/Contents/Resources/")
//        let nordpass = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let adBlock = WebExtensionManager.loadWebExtension(path: "/Applications/NordPass® Password Manager & Digital Vault.app/Contents/PlugIns/NordPass® Password Manager & Digital Vault Extension.appex/Contents/Resources/")
//        let nightEye = WebExtensionManager.loadWebExtension(path: "/Applications/Night Eye.app/Contents/PlugIns/Night Eye Extension.appex/Contents/Resources/")

        return [cookieBgPicker!]
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

    //TODO

//    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowWith options: WKWebExtension.WindowCreationOptions, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void) {
//
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, openNewTabWith options: WKWebExtension.TabCreationOptions, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
//        os_log(.error, log: .extensions, "Open new tab with options")
//        let url = options.url!
//        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController.openNewTab(with: .url(url, source: .ui))
//        completionHandler(nil, nil)
//    }

//    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [WKWebExtensionWindow] {
//        os_log(.error, log: .extensions, "Open window for")
//        return []
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> WKWebExtensionWindow? {
//        os_log(.error, log: .extensions, "Focused window for")
//        return nil
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowWith options: WKWebExtension.WindowCreationOptions, for extensionContext: WKWebExtensionContext) async throws -> WKWebExtensionWindow? {
//        os_log(.error, log: .extensions, "Open new window with")
//        return nil
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext) async throws {
//        os_log(.error, log: .extensions, "Open options page for")
//    }
//
//    private func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<_WKWebExtension.Permission>, in tab: WKWebExtensionTab?, for extensionContext: WKWebExtensionContext) async -> Set<WKWebExtension.Permission> {
//        os_log(.error, log: .extensions, "Open options page for")
//        return Set()
//    }
//
//    private func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: WKWebExtensionTab?, for extensionContext: WKWebExtensionContext) async -> Set<WKWebExtension.MatchPattern> {
//        os_log(.error, log: .extensions, "Prompt for permission match patterns")
//        return Set()
//    }
//
//    private func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: WKWebExtensionTab?, for extensionContext: WKWebExtensionContext) async -> Set<URL> {
//        os_log(.error, log: .extensions, "Prompt for permission match patterns")
//        return Set()
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, sendMessage message: Any, to applicationIdentifier: String?, for extensionContext: WKWebExtensionContext) async throws -> Any? {
//        return message
//    }
//
//    func webExtensionController(_ controller: WKWebExtensionController, connectUsingMessagePort port: WKWebExtension.MessagePort, for extensionContext: WKWebExtensionContext) async throws {
//
//    }

    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        defer {
            completionHandler(nil)
        }
        guard let button = buttonForContext(context) else {
            return
        }
        guard action.presentsPopup, let popupWebView = action.popupWebView else {
            return
        }

        showPopover(popupWebView: popupWebView, button: button)
    }

}
