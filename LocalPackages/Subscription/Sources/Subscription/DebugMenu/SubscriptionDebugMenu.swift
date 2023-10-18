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
import Account

public final class SubscriptionDebugMenu: NSMenuItem {

    var currentViewController: () -> NSViewController?
    private let accountManager = AccountManager()

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init(currentViewController: @escaping () -> NSViewController?) {
        self.currentViewController = currentViewController
        super.init(title: "Subscription", action: nil, keyEquivalent: "")
        self.submenu = submenuItem
    }

    private lazy var submenuItem: NSMenu = {
        let menu = NSMenu(title: "")

        menu.addItem(NSMenuItem(title: "Simulate Subscription Active State (fake token)", action: #selector(simulateSubscriptionActiveState), target: self))
        menu.addItem(NSMenuItem(title: "Clear Subscription Authorization Data", action: #selector(signOut), target: self))
        menu.addItem(NSMenuItem(title: "Show account details", action: #selector(showAccountDetails), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Validate Token", action: #selector(validateToken), target: self))
        menu.addItem(NSMenuItem(title: "Restore Subscription from App Store transaction", action: #selector(restorePurchases), target: self))
        menu.addItem(.separator())
        if #available(macOS 12.0, *) {
            menu.addItem(NSMenuItem(title: "Purchase Subscription from App Store", action: #selector(showPurchaseView), target: self))
        }

        return menu
    }()

    @objc
    func simulateSubscriptionActiveState() {
        accountManager.storeAccount(token: "fake-token", email: "fake@email.com", externalID: "fake-externalID")
    }

    @objc
    func signOut() {
        accountManager.signOut()
    }

    @objc
    func showAccountDetails() {
        let title = accountManager.isSignedIn ? "Authenticated" : "Not Authenticated"
        let message = accountManager.isSignedIn ? ["AuthToken: \(accountManager.authToken ?? "")",
                                                   "AccessToken: \(accountManager.accessToken ?? "")",
                                                   "Email: \(accountManager.email ?? "")",
                                                   "ExternalID: \(accountManager.externalID ?? "")"].joined(separator: "\n") : nil
        showAlert(title: title, message: message)
    }

    @objc
    func validateToken() {
        Task {
            guard let token = accountManager.accessToken else { return }
            switch await AuthService.validateToken(accessToken: token) {
            case .success(let response):
                showAlert(title: "Validate token", message: "\(response)")
            case .failure(let error):
                showAlert(title: "Validate token", message: "\(error)")
            }
        }
    }

    @objc
    func restorePurchases(_ sender: Any?) {
        accountManager.signInByRestoringPastPurchases()
    }

    @IBAction func showPurchaseView(_ sender: Any?) {
        if #available(macOS 12.0, *) {
            currentViewController()?.presentAsSheet(DebugPurchaseViewController())
        }
    }

    private func showAlert(title: String, message: String? = nil) {
        Task { @MainActor in
            let alert = NSAlert.init()
            alert.messageText = title
            if let message = message {
                alert.informativeText = message
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

extension NSMenuItem {

    convenience init(title string: String, action selector: Selector?, target: AnyObject?, keyEquivalent charCode: String = "", representedObject: Any? = nil) {
        self.init(title: string, action: selector, keyEquivalent: charCode)
        self.target = target
        self.representedObject = representedObject
    }
}
