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

private extension URL {

    static var purchaseSubscription: URL {
        URL(string: "https://duckduckgo.com/about")!
    }

    static var subscriptionFAQ: URL {
        URL(string: "https://duckduckgo.com/about")!
    }
}

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isSignedIn: Bool = false
    var sheetModel: SubscriptionAccessModel

    private let accountManager: AccountManager
    private var actionHandler: PreferencesSubscriptionActionHandlers
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    public init(accountManager: AccountManager = AccountManager(), actionHandler: PreferencesSubscriptionActionHandlers, sheetActionHandler: SubscriptionAccessActionHandlers) {
        self.accountManager = accountManager
        self.actionHandler = actionHandler
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
    func learnMoreAction() {
        actionHandler.openURL(.purchaseSubscription)
    }

    @MainActor
    func changePlanOrBillingAction() {
        actionHandler.manageSubscriptionInAppStore()
    }

    @MainActor
    func removeFromThisDeviceAction() {
        accountManager.signOut()
    }

    @MainActor
    func openVPN() {
        actionHandler.openVPN()
    }

    @MainActor
    func openPersonalInformationRemoval() {
        actionHandler.openPersonalInformationRemoval()
    }

    @MainActor
    func openIdentityTheftRestoration() {
        actionHandler.openIdentityTheftRestoration()
    }

    @MainActor
    func openFAQ() {
        actionHandler.openURL(.subscriptionFAQ)
    }
}

public final class PreferencesSubscriptionActionHandlers {
    var openURL: (URL) -> Void
    var manageSubscriptionInAppStore: () -> Void
    var openVPN: () -> Void
    var openPersonalInformationRemoval: () -> Void
    var openIdentityTheftRestoration: () -> Void

    public init(openURL: @escaping (URL) -> Void, manageSubscriptionInAppStore: @escaping () -> Void, openVPN: @escaping () -> Void, openPersonalInformationRemoval: @escaping () -> Void, openIdentityTheftRestoration: @escaping () -> Void) {
        self.openURL = openURL
        self.manageSubscriptionInAppStore = manageSubscriptionInAppStore
        self.openVPN = openVPN
        self.openPersonalInformationRemoval = openPersonalInformationRemoval
        self.openIdentityTheftRestoration = openIdentityTheftRestoration
    }
}
