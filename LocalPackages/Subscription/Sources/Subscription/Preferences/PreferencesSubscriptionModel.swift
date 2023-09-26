//
//  PreferencesSubscriptionModel.swift
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
import Account
//import AppKit

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isSignedIn: Bool = false
    var sheetModel: SubscriptionAccessModel

    private let accountManager: AccountManager
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    public init(accountManager: AccountManager = AccountManager(), sheetActionHandler: SubscriptionAccessActionHandlers) {
        self.accountManager = accountManager
        self.sheetActionHandler = sheetActionHandler

        let isSignedIn = accountManager.isSignedIn
        self.isSignedIn = isSignedIn
        sheetModel = isSignedIn ? ShareSubscriptionAccessModel(actionHandlers: sheetActionHandler, email: accountManager.email) : ActivateSubscriptionAccessModel(actionHandlers: sheetActionHandler)

        NotificationCenter.default.addObserver(forName: .accountDidSignIn, object: nil, queue: .main) { _ in
            self.updateSignInState(true)
        }

        NotificationCenter.default.addObserver(forName: .accountDidSignOut, object: nil, queue: .main) { _ in
            self.updateSignInState(false)
        }
    }

    private func updateSignInState(_ isSignedIn: Bool) {
        self.isSignedIn = isSignedIn
        sheetModel = isSignedIn ? ShareSubscriptionAccessModel(actionHandlers: sheetActionHandler, email: accountManager.email) : ActivateSubscriptionAccessModel(actionHandlers: sheetActionHandler)
    }

    @MainActor
    private func openURL(_ url: URL) {
//        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    @MainActor
    func learnMoreAction() {
//        openURL(.aboutDuckDuckGo)
    }

    @MainActor
    func changePlanOrBillingAction() {
//        NSWorkspace.shared.open(URL(string: "macappstores://apps.apple.com/account/subscriptions")!)
    }

    @MainActor
    func removeFromThisDeviceAction() {
        accountManager.signOut()
    }

    @MainActor
    func openFAQ() {
//        openURL(.aboutDuckDuckGo)
    }

}
