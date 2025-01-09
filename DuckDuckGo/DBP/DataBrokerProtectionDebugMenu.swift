//
//  DataBrokerProtectionDebugMenu.swift
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

import DataBrokerProtection
import Foundation
import AppKit
import Common
import LoginItems
import NetworkProtectionProxy
import os.log

final class DataBrokerProtectionDebugMenu: NSMenu {

    enum EnvironmentTitle: String {
      case staging = "Staging"
      case production = "Production"
    }

    private let waitlistTokenItem = NSMenuItem(title: "Waitlist Token:")
    private let waitlistTimestampItem = NSMenuItem(title: "Waitlist Timestamp:")
    private let waitlistInviteCodeItem = NSMenuItem(title: "Waitlist Invite Code:")
    private let waitlistTermsAndConditionsAcceptedItem = NSMenuItem(title: "T&C Accepted:")

    private let productionURLMenuItem = NSMenuItem(title: "Use Production URL", action: #selector(DataBrokerProtectionDebugMenu.useWebUIProductionURL))

    private let customURLMenuItem = NSMenuItem(title: "Use Custom URL", action: #selector(DataBrokerProtectionDebugMenu.useWebUICustomURL))

    private var databaseBrowserWindowController: NSWindowController?
    private var dataBrokerForceOptOutWindowController: NSWindowController?
    private let customURLLabelMenuItem = NSMenuItem(title: "")

    private let environmentMenu = NSMenu()
    private let statusMenuIconMenu = NSMenuItem(title: "Show Status Menu Icon", action: #selector(DataBrokerProtectionDebugMenu.toggleShowStatusMenuItem))

    private let webUISettings = DataBrokerProtectionWebUIURLSettings(.dbp)
    private let settings = DataBrokerProtectionSettings(defaults: .dbp)

    init() {
        super.init(title: "Personal Information Removal")

        buildItems {
            NSMenuItem(title: "Environment")
                .submenu(environmentMenu)

            NSMenuItem(title: "Background Agent") {
                NSMenuItem(title: "Enable", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentEnable))
                    .targetting(self)

                NSMenuItem(title: "Disable", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentDisable))
                    .targetting(self)

                NSMenuItem(title: "Restart", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentRestart))
                    .targetting(self)

                NSMenuItem.separator()

                NSMenuItem(title: "Show agent IP address", action: #selector(DataBrokerProtectionDebugMenu.showAgentIPAddress))
                    .targetting(self)
            }

            NSMenuItem(title: "Operations") {
                NSMenuItem(title: "Hidden WebView") {
                    menuItem(withTitle: "Run queued operations",
                             action: #selector(DataBrokerProtectionDebugMenu.startScheduledOperations(_:)),
                             representedObject: false)

                    menuItem(withTitle: "Run scan operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runScanOperations(_:)),
                             representedObject: false)

                    menuItem(withTitle: "Run opt-out operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runOptoutOperations(_:)),
                             representedObject: false)
                }

                NSMenuItem(title: "Visible WebView") {
                    menuItem(withTitle: "Run queued operations",
                             action: #selector(DataBrokerProtectionDebugMenu.startScheduledOperations(_:)),
                             representedObject: true)

                    menuItem(withTitle: "Run scan operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runScanOperations(_:)),
                             representedObject: true)

                    menuItem(withTitle: "Run opt-out operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runOptoutOperations(_:)),
                             representedObject: true)
                }
            }

            NSMenuItem(title: "Web UI") {
                productionURLMenuItem.targetting(self)
                customURLMenuItem.targetting(self)

                NSMenuItem.separator()

                NSMenuItem(title: "Set Custom URL", action: #selector(DataBrokerProtectionDebugMenu.setWebUICustomURL))
                    .targetting(self)
                NSMenuItem(title: "Reset Custom URL", action: #selector(DataBrokerProtectionDebugMenu.resetCustomURL))
                    .targetting(self)

                customURLLabelMenuItem
            }

            NSMenuItem.separator()

            statusMenuIconMenu.targetting(self)

            NSMenuItem(title: "Show DB Browser", action: #selector(DataBrokerProtectionDebugMenu.showDatabaseBrowser))
                .targetting(self)
            NSMenuItem(title: "Force Profile Removal", action: #selector(DataBrokerProtectionDebugMenu.showForceOptOutWindow))
                .targetting(self)
            NSMenuItem(title: "Force broker JSON files update", action: #selector(DataBrokerProtectionDebugMenu.forceBrokerJSONFilesUpdate))
                .targetting(self)
            NSMenuItem(title: "Run Personal Information Removal Debug Mode", action: #selector(DataBrokerProtectionDebugMenu.runCustomJSON))
                .targetting(self)
            NSMenuItem(title: "Reset All State and Delete All Data", action: #selector(DataBrokerProtectionDebugMenu.deleteAllDataAndStopAgent))
                .targetting(self)

            populateDataBrokerProtectionEnvironmentListMenuItems()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Menu State Update

    override func update() {
        updateWebUIMenuItemsState()
        updateEnvironmentMenu()
        updateShowStatusMenuIconMenu()
    }

    // MARK: - Menu functions

    @objc private func useWebUIProductionURL() {
        webUISettings.setURLType(.production)
    }

    @objc private func useWebUICustomURL() {
        webUISettings.setURLType(.custom)
        webUISettings.setCustomURL(webUISettings.productionURL)
    }

    @objc private func resetCustomURL() {
        webUISettings.setURLType(.production)
        webUISettings.setCustomURL(webUISettings.productionURL)
    }

    @objc private func setWebUICustomURL() {
        showCustomURLAlert { [weak self] value in

            guard let value = value, let url = URL(string: value), url.isValid else { return false }

            self?.webUISettings.setCustomURL(value)
            return true
        }
    }

    @objc private func startScheduledOperations(_ sender: NSMenuItem) {
        Logger.dataBrokerProtection.log("Running queued operations...")
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.loginItemInterface.startScheduledOperations(showWebView: showWebView)
    }

    @objc private func runScanOperations(_ sender: NSMenuItem) {
        Logger.dataBrokerProtection.log("Running scan operations...")
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.loginItemInterface.startImmediateOperations(showWebView: showWebView)
    }

    @objc private func runOptoutOperations(_ sender: NSMenuItem) {
        Logger.dataBrokerProtection.log("Running Optout operations...")
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.loginItemInterface.runAllOptOuts(showWebView: showWebView)
    }

    @objc private func backgroundAgentRestart() {
        LoginItemsManager().restartLoginItems([LoginItem.dbpBackgroundAgent])
    }

    @objc private func backgroundAgentDisable() {
        LoginItemsManager().disableLoginItems([LoginItem.dbpBackgroundAgent])
    }

    @objc private func backgroundAgentEnable() {
        LoginItemsManager().enableLoginItems([LoginItem.dbpBackgroundAgent])
    }

    @objc private func deleteAllDataAndStopAgent() {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.removeAllDBPStateAndDataAlert().runModal() else { return }
            DataBrokerProtectionFeatureDisabler().disableAndDelete()
        }
    }

    @objc private func showDatabaseBrowser() {
        let viewController = DataBrokerDatabaseBrowserViewController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)

        window.contentViewController = viewController
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        databaseBrowserWindowController = NSWindowController(window: window)
        databaseBrowserWindowController?.showWindow(nil)
        window.delegate = self
    }

    @objc private func showAgentIPAddress() {
        DataBrokerProtectionManager.shared.showAgentIPAddress()
    }

    @objc private func showForceOptOutWindow() {
        let viewController = DataBrokerForceOptOutViewController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)

        window.contentViewController = viewController
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        dataBrokerForceOptOutWindowController = NSWindowController(window: window)
        dataBrokerForceOptOutWindowController?.showWindow(nil)
        window.delegate = self
    }

    @objc private func runCustomJSON() {
        let authenticationManager = DataBrokerAuthenticationManagerBuilder.buildAuthenticationManager(subscriptionManager: Application.appDelegate.subscriptionManager)
        let viewController = DataBrokerRunCustomJSONViewController(authenticationManager: authenticationManager)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)

        window.contentViewController = viewController
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        databaseBrowserWindowController = NSWindowController(window: window)
        databaseBrowserWindowController?.showWindow(nil)
        window.delegate = self
    }

    @objc private func forceBrokerJSONFilesUpdate() {
        if let updater = DefaultDataBrokerProtectionBrokerUpdater.provideForDebug() {
            updater.updateBrokers()
        }
    }

    @objc private func toggleShowStatusMenuItem() {
        settings.showInMenuBar.toggle()
    }

    // MARK: - Utility Functions

    private func populateDataBrokerProtectionEnvironmentListMenuItems() {
        environmentMenu.items = [
            NSMenuItem(title: "⚠️ The environment can be set in the Subscription > Environment menu", action: nil, target: nil),
            NSMenuItem(title: EnvironmentTitle.production.rawValue, action: nil, target: nil, keyEquivalent: ""),
            NSMenuItem(title: EnvironmentTitle.staging.rawValue, action: nil, target: nil, keyEquivalent: ""),
        ]
    }

    func showCustomURLAlert(callback: @escaping (String?) -> Bool) {
        let alert = NSAlert()
        alert.messageText = "Enter URL"
        alert.addButton(withTitle: "Accept")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = inputTextField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if !callback(inputTextField.stringValue) {
                let invalidAlert = NSAlert()
                invalidAlert.messageText = "Invalid URL"
                invalidAlert.informativeText = "Please enter a valid URL."
                invalidAlert.addButton(withTitle: "OK")
                invalidAlert.runModal()
            }
        } else {
            _ = callback(nil)
        }
    }

    private func updateWebUIMenuItemsState() {
        productionURLMenuItem.state = webUISettings.selectedURLType == .custom ? .off : .on
        customURLMenuItem.state = webUISettings.selectedURLType == .custom ? .on : .off

        customURLLabelMenuItem.title = "Custom URL: [\(webUISettings.customURL ?? "")]"
    }

    func menuItem(withTitle title: String, action: Selector, representedObject: Any?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = representedObject
        return menuItem
    }

    private func updateEnvironmentMenu() {
        let selectedEnvironment = settings.selectedEnvironment
        guard environmentMenu.items.count == 3 else { return }

        environmentMenu.items[1].state = selectedEnvironment == .production ? .on: .off
        environmentMenu.items[2].state = selectedEnvironment == .staging ? .on: .off
    }

    private func updateShowStatusMenuIconMenu() {
        statusMenuIconMenu.state = settings.showInMenuBar ? .on : .off
    }
}

extension DataBrokerProtectionDebugMenu: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        databaseBrowserWindowController = nil
        dataBrokerForceOptOutWindowController = nil
    }
}
