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

public final class SubscriptionDebugMenu: NSMenuItem {

    private var subscriptionManager: SubscriptionManaging
    private lazy var authService = subscriptionManager.serviceProvider.makeAuthService()
    private lazy var subscriptionService = subscriptionManager.serviceProvider.makeSubscriptionService()

    var persistSubscriptionServiceEnvironment: (SubscriptionServiceEnvironment) -> Void

    var isInternalTestingEnabled: () -> Bool
    var updateInternalTestingFlag: (Bool) -> Void

    private var purchasePlatformItem: NSMenuItem?
    private var serviceEnvironmentItem: NSMenuItem?

    var currentViewController: () -> NSViewController?
    private let accountManager: AccountManaging

    private var _purchaseManager: Any?
    @available(macOS 12.0, *)
    fileprivate var purchaseManager: PurchaseManager {
        if _purchaseManager == nil {
            _purchaseManager = PurchaseManager()
        }
        // swiftlint:disable:next force_cast
        return _purchaseManager as! PurchaseManager
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init(subscriptionManager: SubscriptionManaging,
                persistSubscriptionServiceEnvironment: @escaping (SubscriptionServiceEnvironment) -> Void,
                isInternalTestingEnabled: @escaping () -> Bool,
                updateInternalTestingFlag: @escaping (Bool) -> Void,
                currentViewController: @escaping () -> NSViewController?) {
        self.subscriptionManager = subscriptionManager
        self.persistSubscriptionServiceEnvironment = persistSubscriptionServiceEnvironment
        self.isInternalTestingEnabled = isInternalTestingEnabled
        self.updateInternalTestingFlag = updateInternalTestingFlag
        self.currentViewController = currentViewController
        self.accountManager = subscriptionManager.accountManager
        super.init(title: "Subscription", action: nil, keyEquivalent: "")
        self.submenu = makeSubmenu()
    }

    private func makeSubmenu() -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(NSMenuItem(title: "Simulate Subscription Active State (fake token)", action: #selector(simulateSubscriptionActiveState), target: self))
        menu.addItem(NSMenuItem(title: "Clear Subscription Authorization Data", action: #selector(signOut), target: self))
        menu.addItem(NSMenuItem(title: "Show account details", action: #selector(showAccountDetails), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Validate Token", action: #selector(validateToken), target: self))
        menu.addItem(NSMenuItem(title: "Check Entitlements", action: #selector(checkEntitlements), target: self))
        menu.addItem(NSMenuItem(title: "Get Subscription Info", action: #selector(getSubscriptionDetails), target: self))
        menu.addItem(NSMenuItem(title: "Restore Subscription from App Store transaction", action: #selector(restorePurchases), target: self))
        menu.addItem(NSMenuItem(title: "Post didSignIn notification", action: #selector(postDidSignInNotification), target: self))
        menu.addItem(.separator())
        if #available(macOS 12.0, *) {
            menu.addItem(NSMenuItem(title: "Sync App Store AppleID Account (re- sign-in)", action: #selector(syncAppleIDAccount), target: self))
            menu.addItem(NSMenuItem(title: "Purchase Subscription from App Store", action: #selector(showPurchaseView), target: self))
        }

        menu.addItem(.separator())

        let purchasePlatformItem = NSMenuItem(title: "Purchase platform", action: nil, target: nil)
        menu.addItem(purchasePlatformItem)
        self.purchasePlatformItem = purchasePlatformItem

        let environmentItem = NSMenuItem(title: "Environment", action: nil, target: nil)
        menu.addItem(environmentItem)
        self.serviceEnvironmentItem = environmentItem

        menu.addItem(.separator())

        let internalTestingItem = NSMenuItem(title: "Internal testing", action: #selector(toggleInternalTesting), target: self)
        internalTestingItem.state = isInternalTestingEnabled() ? .on : .off
        menu.addItem(internalTestingItem)

        menu.delegate = self

        return menu
    }

    private func makePurchasePlatformSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Select purchase platform:")

        let currentPlatform = subscriptionManager.configuration.currentPurchasePlatform

        let appStoreItem = NSMenuItem(title: "App Store", action: #selector(setPlatformToAppStore), target: self)
        if currentPlatform == .appStore {
            appStoreItem.state = .on
            appStoreItem.isEnabled = false
            appStoreItem.action = nil
            appStoreItem.target = nil
        }
        menu.addItem(appStoreItem)

        let stripeItem = NSMenuItem(title: "Stripe", action: #selector(setPlatformToStripe), target: self)
        if currentPlatform == .stripe {
            stripeItem.state = .on
            stripeItem.isEnabled = false
            stripeItem.action = nil
            stripeItem.target = nil
        }
        menu.addItem(stripeItem)

        menu.addItem(.separator())

        let disclaimerItem = NSMenuItem(title: "⚠️ Change not persisted between app restarts", action: nil, target: nil)
        menu.addItem(disclaimerItem)

        return menu
    }

    private func makeEnvironmentSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Select environment:")

        let currentEnvironment = subscriptionManager.configuration.currentServiceEnvironment

        let stagingItem = NSMenuItem(title: "Staging", action: #selector(setEnvironmentToStaging), target: self)
        stagingItem.state = currentEnvironment == .staging ? .on : .off
        if currentEnvironment == .staging {
            stagingItem.isEnabled = false
            stagingItem.action = nil
            stagingItem.target = nil
        }
        menu.addItem(stagingItem)

        let productionItem = NSMenuItem(title: "Production", action: #selector(setEnvironmentToProduction), target: self)
        productionItem.state = currentEnvironment == .production ? .on : .off
        if currentEnvironment == .production {
            productionItem.isEnabled = false
            productionItem.action = nil
            productionItem.target = nil
        }
        menu.addItem(productionItem)

        return menu
    }

    @objc
    func simulateSubscriptionActiveState() {
        subscriptionManager.tokenStorage.accessToken = "fake-token"
        accountManager.storeAccount(token: "fake-token", email: "fake@email.com", externalID: "123")
    }

    @objc
    func signOut() {
        subscriptionManager.signOut()
    }

    @objc
    func showAccountDetails() {
        let title = subscriptionManager.isUserAuthenticated ? "Authenticated" : "Not Authenticated"
        let message = subscriptionManager.isUserAuthenticated ? ["AuthToken: \(subscriptionManager.tokenStorage.authToken ?? "")",
                                                   "AccessToken: \(subscriptionManager.tokenStorage.accessToken ?? "")",
                                                                 "Email: \(subscriptionManager.accountStorage.email ?? "")"].joined(separator: "\n") : nil
        showAlert(title: title, message: message)
    }

    @objc
    func validateToken() {
        Task {
            guard let token = subscriptionManager.tokenStorage.accessToken else { return }
            switch await authService.validateToken(accessToken: token) {
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
                if case let .success(result) = await accountManager.hasEntitlement(for: entitlement) {
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
            guard let token = subscriptionManager.tokenStorage.accessToken else { return }
            switch await subscriptionService.getSubscription(accessToken: token) {
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
        Task {
            await purchaseManager.syncAppleIDAccount()
        }
    }

    @IBAction func showPurchaseView(_ sender: Any?) {
        if #available(macOS 12.0, *) {
            currentViewController()?.presentAsSheet(DebugPurchaseViewController(subscriptionManager: subscriptionManager))
        }
    }

    @IBAction func setPlatformToAppStore(_ sender: Any?) {
        askAndUpdatePlatform(to: .appStore)
    }

    @IBAction func setPlatformToStripe(_ sender: Any?) {
        askAndUpdatePlatform(to: .stripe)
    }

    private func askAndUpdatePlatform(to newPlatform: SubscriptionPurchasePlatform) {
        let alert = makeAlert(title: "Are you sure you want to change the purchase platform to \(newPlatform.rawValue.capitalized)",
                              message: "This setting is not persisted between app runs. After restarting the app it returns to the default determined on app's distribution method.",
                              buttonNames: ["Yes", "No"])
        let response = alert.runModal()

        guard case .alertFirstButtonReturn = response else { return }

        if let configuration = subscriptionManager.configuration as? DebugSubscriptionConfiguration {
            configuration.updatePurchasePlatform(to: newPlatform)
        }
    }

    @IBAction func setEnvironmentToStaging(_ sender: Any?) {
        askAndUpdateEnvironment(to: .staging)
    }

    @IBAction func setEnvironmentToProduction(_ sender: Any?) {
        askAndUpdateEnvironment(to: .production)
    }

    private func askAndUpdateEnvironment(to newEnvironment: SubscriptionServiceEnvironment) {
        let alert = makeAlert(title: "Are you sure you want to change the environment to \(newEnvironment.rawValue.capitalized)",
                              message: "Please make sure you have manually removed your current active Subscription and reset all related features. \nYou may also need to change environment of related features e.g. Network Protection's to a matching one.",
                              buttonNames: ["Yes", "No"])
        let response = alert.runModal()

        guard case .alertFirstButtonReturn = response else { return }


        if let configuration = subscriptionManager.configuration as? DebugSubscriptionConfiguration {
            configuration.updateServiceEnvironment(to: newEnvironment)
            persistSubscriptionServiceEnvironment(newEnvironment)
        }
    }

    @objc
    func postDidSignInNotification(_ sender: Any?) {
        NotificationCenter.default.post(name: .accountDidSignIn, object: self, userInfo: nil)
    }

    @objc
    func restorePurchases(_ sender: Any?) {
        if #available(macOS 12.0, *) {
            Task {
                await subscriptionManager.flowProvider.appStoreRestoreFlow.restoreAccountFromPastPurchase()
            }
        }
    }

    @objc
    func toggleInternalTesting(_ sender: Any?) {
        Task { @MainActor in
            let currentValue = isInternalTestingEnabled()
            let shouldShowAlert = currentValue == false

            if shouldShowAlert {
                let alert = makeAlert(title: "Are you sure you want to enable internal testing",
                                      message: "Only enable this option if you are participating in internal testing and have been requested to do so.",
                                      buttonNames: ["Yes", "No"])
                let response = alert.runModal()

                guard case .alertFirstButtonReturn = response else { return }
            }

            updateInternalTestingFlag(!currentValue)
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
        serviceEnvironmentItem?.submenu = makeEnvironmentSubmenu()
    }
}
