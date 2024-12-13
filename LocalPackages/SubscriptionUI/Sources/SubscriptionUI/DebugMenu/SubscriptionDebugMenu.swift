//
//  SubscriptionDebugMenu.swift
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

import AppKit
import Subscription
import StoreKit

public final class SubscriptionDebugMenu: NSMenuItem {

    var currentEnvironment: SubscriptionEnvironment
    var updateServiceEnvironment: (SubscriptionEnvironment.ServiceEnvironment) -> Void
    var updatePurchasingPlatform: (SubscriptionEnvironment.PurchasePlatform) -> Void
    var openSubscriptionTab: (URL) -> Void

    private var purchasePlatformItem: NSMenuItem?
    private var regionOverrideItem: NSMenuItem?

    var currentViewController: () -> NSViewController?
    let subscriptionManager: SubscriptionManager
    let subscriptionUserDefaults: UserDefaults
    var accountManager: AccountManager {
        subscriptionManager.accountManager
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init(currentEnvironment: SubscriptionEnvironment,
                updateServiceEnvironment: @escaping (SubscriptionEnvironment.ServiceEnvironment) -> Void,
                updatePurchasingPlatform: @escaping (SubscriptionEnvironment.PurchasePlatform) -> Void,
                currentViewController: @escaping () -> NSViewController?,
                openSubscriptionTab: @escaping (URL) -> Void,
                subscriptionManager: SubscriptionManager,
                subscriptionUserDefaults: UserDefaults) {
        self.currentEnvironment = currentEnvironment
        self.updateServiceEnvironment = updateServiceEnvironment
        self.updatePurchasingPlatform = updatePurchasingPlatform
        self.currentViewController = currentViewController
        self.openSubscriptionTab = openSubscriptionTab
        self.subscriptionManager = subscriptionManager
        self.subscriptionUserDefaults = subscriptionUserDefaults
        super.init(title: "Subscription", action: nil, keyEquivalent: "")
        self.submenu = makeSubmenu()
    }

    private func makeSubmenu() -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(NSMenuItem(title: "I Have a Subscription", action: #selector(activateSubscription), target: self))
        menu.addItem(NSMenuItem(title: "Remove Subscription From This Device", action: #selector(signOut), target: self))
        menu.addItem(NSMenuItem(title: "Show Account Details", action: #selector(showAccountDetails), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Validate Token", action: #selector(validateToken), target: self))
        menu.addItem(NSMenuItem(title: "Check Entitlements", action: #selector(checkEntitlements), target: self))
        menu.addItem(NSMenuItem(title: "Get Subscription Details", action: #selector(getSubscriptionDetails), target: self))

        if #available(macOS 12.0, *) {
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Sync App Store AppleID Account (re- sign-in)", action: #selector(syncAppleIDAccount), target: self))
            menu.addItem(NSMenuItem(title: "Purchase Subscription from App Store", action: #selector(showPurchaseView), target: self))
            menu.addItem(NSMenuItem(title: "Restore Subscription from App Store transaction", action: #selector(restorePurchases), target: self))
        }

        menu.addItem(.separator())

        let purchasePlatformItem = NSMenuItem(title: "Purchase platform", action: nil, target: nil)
        menu.addItem(purchasePlatformItem)
        self.purchasePlatformItem = purchasePlatformItem

        let environmentItem = NSMenuItem(title: "Environment", action: nil, target: nil)
        environmentItem.submenu = makeEnvironmentSubmenu()
        menu.addItem(environmentItem)

        menu.addItem(.separator())
        let storefrontID = SKPaymentQueue.default().storefront?.identifier ?? "nil"
        menu.addItem(NSMenuItem(title: "Storefront ID: \(storefrontID)", action: nil, target: nil))
        let storefrontCountryCode = SKPaymentQueue.default().storefront?.countryCode ?? "nil"
        menu.addItem(NSMenuItem(title: "Storefront Country Code: \(storefrontCountryCode)", action: nil, target: nil))

        let regionOverrideItem = NSMenuItem(title: "Region override for App Store Sandbox", action: nil, target: nil)
        menu.addItem(regionOverrideItem)
        self.regionOverrideItem = regionOverrideItem

        menu.delegate = self

        return menu
    }

    private func makePurchasePlatformSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Select purchase platform:")
        let appStoreItem = NSMenuItem(title: "App Store", action: #selector(setPlatformToAppStore), target: self)
        if currentEnvironment.purchasePlatform == .appStore {
            appStoreItem.state = .on
            appStoreItem.isEnabled = false
            appStoreItem.action = nil
            appStoreItem.target = nil
        }
        menu.addItem(appStoreItem)

        let stripeItem = NSMenuItem(title: "Stripe", action: #selector(setPlatformToStripe), target: self)
        if currentEnvironment.purchasePlatform == .stripe {
            stripeItem.state = .on
            stripeItem.isEnabled = false
            stripeItem.action = nil
            stripeItem.target = nil
        }
        menu.addItem(stripeItem)

        menu.addItem(.separator())

        let disclaimerItem = NSMenuItem(title: "⚠️ App restart required! The changes are persistent", action: nil, target: nil)
        menu.addItem(disclaimerItem)

        return menu
    }

    private func makeEnvironmentSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Select environment:")

        let stagingItem = NSMenuItem(title: "Staging", action: #selector(setEnvironmentToStaging), target: self)
        let isStaging = currentEnvironment.serviceEnvironment == .staging
        stagingItem.state = isStaging ? .on : .off
        if isStaging {
            stagingItem.isEnabled = false
            stagingItem.action = nil
            stagingItem.target = nil
        }
        menu.addItem(stagingItem)

        let productionItem = NSMenuItem(title: "Production", action: #selector(setEnvironmentToProduction), target: self)
        let isProduction = currentEnvironment.serviceEnvironment == .production
        productionItem.state = isProduction ? .on : .off
        if isProduction {
            productionItem.isEnabled = false
            productionItem.action = nil
            productionItem.target = nil
        }
        menu.addItem(productionItem)

        let disclaimerItem = NSMenuItem(title: "⚠️ App restart required! The changes are persistent", action: nil, target: nil)
        menu.addItem(disclaimerItem)

        return menu
    }

    private func makeRegionOverrideItemSubmenu() -> NSMenu {
        let menu = NSMenu(title: "")

        let currentRegionOverride = subscriptionUserDefaults.storefrontRegionOverride

        let usaItem = NSMenuItem(title: "USA", action: #selector(setRegionOverrideToUSA), target: self)
        if currentRegionOverride == .usa {
            usaItem.state = .on
            usaItem.isEnabled = false
            usaItem.action = nil
            usaItem.target = nil
        }
        menu.addItem(usaItem)

        let rowItem = NSMenuItem(title: "Rest of World", action: #selector(setRegionOverrideToROW), target: self)
        if currentRegionOverride == .restOfWorld {
            rowItem.state = .on
            rowItem.isEnabled = false
            rowItem.action = nil
            rowItem.target = nil
        }
        menu.addItem(rowItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear storefront region override", action: #selector(clearRegionOverride), target: self)
        menu.addItem(clearItem)

        return menu
    }

    private func refreshSubmenu() {
        self.submenu = makeSubmenu()
    }

    @objc
    func activateSubscription() {
        let url = subscriptionManager.url(for: .activateViaEmail)
        openSubscriptionTab(url)
    }

    @objc
    func signOut() {
        accountManager.signOut()
    }

    @objc
    func showAccountDetails() {
        let title = accountManager.isUserAuthenticated ? "Authenticated" : "Not Authenticated"
        let message = accountManager.isUserAuthenticated ? ["AuthToken: \(accountManager.authToken ?? "")",
                                                                                "AccessToken: \(accountManager.accessToken ?? "")",
                                                                                "Email: \(accountManager.email ?? "")"].joined(separator: "\n") : nil
        showAlert(title: title, message: message)
    }

    @objc
    func validateToken() {
        Task {
            guard let token = accountManager.accessToken else { return }
            switch await subscriptionManager.authEndpointService.validateToken(accessToken: token) {
            case .success(let response):
                showAlert(title: "Validate token", message: "\(response)")
            case .failure(let error):
                showAlert(title: "Validate token", message: "\(error)")
            }
        }
    }

    @objc
    func checkEntitlements() {
        Task {
            var results: [String] = []

            let entitlements: [Entitlement.ProductName] = [.networkProtection, .dataBrokerProtection, .identityTheftRestoration]
            for entitlement in entitlements {
                if case let .success(result) = await accountManager.hasEntitlement(forProductName: entitlement, cachePolicy: .reloadIgnoringLocalCacheData) {
                    let resultSummary = "Entitlement check for \(entitlement.rawValue): \(result)"
                    results.append(resultSummary)
                    print(resultSummary)
                }
            }

            showAlert(title: "Check Entitlements", message: results.joined(separator: "\n"))
        }
    }

    @objc
    func getSubscriptionDetails() {
        Task {
            guard let token = accountManager.accessToken else { return }
            switch await subscriptionManager.subscriptionEndpointService.getSubscription(accessToken: token, cachePolicy: .reloadIgnoringLocalCacheData) {
            case .success(let response):
                showAlert(title: "Subscription info", message: "\(response)")
            case .failure(let error):
                showAlert(title: "Subscription info", message: "\(error)")
            }
        }
    }

    @available(macOS 12.0, *)
    @objc
    func syncAppleIDAccount() {
        Task { @MainActor in
            try? await subscriptionManager.storePurchaseManager().syncAppleIDAccount()
        }
    }

    @IBAction func showPurchaseView(_ sender: Any?) {
        if #available(macOS 12.0, *) {
            let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(accountManager: subscriptionManager.accountManager,
                                                                 storePurchaseManager: subscriptionManager.storePurchaseManager(),
                                                                 subscriptionEndpointService: subscriptionManager.subscriptionEndpointService,
                                                                 authEndpointService: subscriptionManager.authEndpointService)
            let appStorePurchaseFlow = DefaultAppStorePurchaseFlow(subscriptionEndpointService: subscriptionManager.subscriptionEndpointService,
                                                                   storePurchaseManager: subscriptionManager.storePurchaseManager(),
                                                                   accountManager: subscriptionManager.accountManager,
                                                                   appStoreRestoreFlow: appStoreRestoreFlow,
                                                                   authEndpointService: subscriptionManager.authEndpointService)
            // swiftlint:disable:next force_cast
            let vc = DebugPurchaseViewController(storePurchaseManager: subscriptionManager.storePurchaseManager() as! DefaultStorePurchaseManager, appStorePurchaseFlow: appStorePurchaseFlow)
            currentViewController()?.presentAsSheet(vc)
        }
    }

    // MARK: - Platform

    @IBAction func setPlatformToAppStore(_ sender: Any?) {
        askAndUpdatePlatform(to: .appStore)
    }

    @IBAction func setPlatformToStripe(_ sender: Any?) {
        askAndUpdatePlatform(to: .stripe)
    }

    private func askAndUpdatePlatform(to newPlatform: SubscriptionEnvironment.PurchasePlatform) {
        let alert = makeAlert(title: "Are you sure you want to change the purchase platform to \(newPlatform.rawValue.capitalized)",
                              message: "This setting IS persisted between app runs. This action will close the app, do you want to proceed?",
                              buttonNames: ["Yes", "No"])
        let response = alert.runModal()
        guard case .alertFirstButtonReturn = response else { return }
        updatePurchasingPlatform(newPlatform)
        closeTheApp()
    }

    // MARK: - Environment

    @IBAction func setEnvironmentToStaging(_ sender: Any?) {
        askAndUpdateServiceEnvironment(to: SubscriptionEnvironment.ServiceEnvironment.staging)
    }

    @IBAction func setEnvironmentToProduction(_ sender: Any?) {
        askAndUpdateServiceEnvironment(to: SubscriptionEnvironment.ServiceEnvironment.production)
    }

    private func askAndUpdateServiceEnvironment(to newServiceEnvironment: SubscriptionEnvironment.ServiceEnvironment) {
        let alert = makeAlert(title: "Are you sure you want to change the environment to \(newServiceEnvironment.description.capitalized)",
                              message: """
                              Please make sure you have manually removed your current active Subscription and reset all related features.
                              You may also need to change environment of related features.
                              This setting IS persisted between app runs. This action will close the app, do you want to proceed?
                              """,
                              buttonNames: ["Yes", "No"])
        let response = alert.runModal()
        guard case .alertFirstButtonReturn = response else { return }
        updateServiceEnvironment(newServiceEnvironment)
        closeTheApp()
    }

    func closeTheApp() {
      NSApp.terminate(self)
    }

    // MARK: - Region override

    @IBAction func clearRegionOverride(_ sender: Any?) {
        updateRegionOverride(to: nil)
    }

    @IBAction func setRegionOverrideToUSA(_ sender: Any?) {
        updateRegionOverride(to: .usa)
    }

    @IBAction func setRegionOverrideToROW(_ sender: Any?) {
        updateRegionOverride(to: .restOfWorld)
    }

    private func updateRegionOverride(to region: SubscriptionRegion?) {
        self.subscriptionUserDefaults.storefrontRegionOverride = region

        if #available(macOS 12.0, *) {
            Task {
                await subscriptionManager.storePurchaseManager().updateAvailableProducts()
            }
        }
    }

    // MARK: -

    @objc
    func restorePurchases(_ sender: Any?) {
        if #available(macOS 12.0, *) {
            Task {
                let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(accountManager: subscriptionManager.accountManager,
                                                                     storePurchaseManager: subscriptionManager.storePurchaseManager(),
                                                                     subscriptionEndpointService: subscriptionManager.subscriptionEndpointService,
                                                                     authEndpointService: subscriptionManager.authEndpointService)
                await appStoreRestoreFlow.restoreAccountFromPastPurchase()
            }
        }
    }

    private func showAlert(title: String, message: String? = nil) {
        Task { @MainActor in
            let alert = makeAlert(title: title, message: message)
            alert.runModal()
        }
    }

    private func makeAlert(title: String, message: String? = nil, buttonNames: [String] = ["Ok"]) -> NSAlert{
        let alert = NSAlert()
        alert.messageText = title
        if let message = message {
            alert.informativeText = message
        }

        for buttonName in buttonNames {
            alert.addButton(withTitle: buttonName)
        }
        alert.accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 0))
        return alert
    }
}

extension NSMenuItem {

    convenience init(title string: String, action selector: Selector?, target: AnyObject?, keyEquivalent charCode: String = "", representedObject: Any? = nil) {
        self.init(title: string, action: selector, keyEquivalent: charCode)
        self.target = target
        self.representedObject = representedObject
    }
}

extension SubscriptionDebugMenu: NSMenuDelegate {

    public func menuWillOpen(_ menu: NSMenu) {
        purchasePlatformItem?.submenu = makePurchasePlatformSubmenu()
        regionOverrideItem?.submenu = makeRegionOverrideItemSubmenu()
    }
}
