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
import Subscription

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isUserAuthenticated: Bool = false
    @Published var hasEntitlements: Bool = false
    @Published var subscriptionDetails: String?

    private var subscriptionPlatform: SubscriptionService.GetSubscriptionDetailsResponse.Platform?

    lazy var sheetModel: SubscriptionAccessModel = makeSubscriptionAccessModel()

    private let accountManager: AccountManager
    private var actionHandler: PreferencesSubscriptionActionHandlers
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    private var signInObserver: Any?
    private var signOutObserver: Any?

    public init(accountManager: AccountManager = AccountManager(), actionHandler: PreferencesSubscriptionActionHandlers, sheetActionHandler: SubscriptionAccessActionHandlers) {
        self.accountManager = accountManager
        self.actionHandler = actionHandler
        self.sheetActionHandler = sheetActionHandler

        self.isUserAuthenticated = accountManager.isUserAuthenticated
        self.hasEntitlements = self.isUserAuthenticated

        if let cachedDate = SubscriptionService.cachedSubscriptionDetailsResponse?.expiresOrRenewsAt {
            updateDescription(for: cachedDate)
        }

        signInObserver = NotificationCenter.default.addObserver(forName: .accountDidSignIn, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState(true)
        }

        signOutObserver = NotificationCenter.default.addObserver(forName: .accountDidSignOut, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState(false)
        }
    }

    deinit {
        if let signInObserver {
            NotificationCenter.default.removeObserver(signInObserver)
        }

        if let signOutObserver {
            NotificationCenter.default.removeObserver(signOutObserver)
        }
    }

    private func makeSubscriptionAccessModel() -> SubscriptionAccessModel {
        if accountManager.isUserAuthenticated {
            ShareSubscriptionAccessModel(actionHandlers: sheetActionHandler, email: accountManager.email)
        } else {
            ActivateSubscriptionAccessModel(actionHandlers: sheetActionHandler)
        }
    }

    private func updateUserAuthenticatedState(_ isUserAuthenticated: Bool) {
        self.isUserAuthenticated = isUserAuthenticated
        sheetModel = makeSubscriptionAccessModel()
    }

    @MainActor
    func learnMoreAction() {
        actionHandler.openURL(.purchaseSubscription)
    }

    enum ChangePlanOrBillingAction {
        case presentSheet(ManageSubscriptionSheet)
        case navigateToManageSubscription(() -> Void)
    }

    @MainActor
    func changePlanOrBillingAction() async -> ChangePlanOrBillingAction {
        switch subscriptionPlatform {
        case .apple:
            if await confirmIfSignedInToSameAccount() {
                return .navigateToManageSubscription { [weak self] in
                    self?.actionHandler.changePlanOrBilling(.appStore)
                }
            } else {
                return .presentSheet(.apple)
            }
        case .google:
            return .presentSheet(.google)
        case .stripe:
            return .navigateToManageSubscription { [weak self] in
                self?.actionHandler.changePlanOrBilling(.stripe)
            }
        default:
            return .navigateToManageSubscription { }
        }
    }

    private func confirmIfSignedInToSameAccount() async -> Bool {
        if #available(macOS 12.0, *) {
            guard let lastTransactionJWSRepresentation = await PurchaseManager.mostRecentTransaction() else { return false }

            switch await AuthService.storeLogin(signature: lastTransactionJWSRepresentation) {
            case .success(let response):
                return response.externalID == AccountManager().externalID
            case .failure:
                return false
            }
        }

        return false
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

    @MainActor
    func fetchAndUpdateSubscriptionDetails() {
        Task {
            guard let token = accountManager.accessToken else { return }

            if let cachedDate = SubscriptionService.cachedSubscriptionDetailsResponse?.expiresOrRenewsAt {
                updateDescription(for: cachedDate)
                self.hasEntitlements = cachedDate.timeIntervalSinceNow > 0
            }

            if case .success(let response) = await SubscriptionService.getSubscriptionDetails(token: token) {
                if !response.isSubscriptionActive {
                    AccountManager().signOut()
                    return
                }

                updateDescription(for: response.expiresOrRenewsAt)

                subscriptionPlatform = response.platform
            }

            self.hasEntitlements = await AccountManager().hasEntitlement(for: "dummy1")
        }
    }

    private func updateDescription(for date: Date) {
        self.subscriptionDetails = UserText.preferencesSubscriptionActiveCaption(formattedDate: dateFormatter.string(from: date))
    }

    private var dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()
}

public final class PreferencesSubscriptionActionHandlers {
    var openURL: (URL) -> Void
    var changePlanOrBilling: (SubscriptionPurchaseEnvironment.Environment) -> Void
    var openVPN: () -> Void
    var openPersonalInformationRemoval: () -> Void
    var openIdentityTheftRestoration: () -> Void

    public init(openURL: @escaping (URL) -> Void, changePlanOrBilling: @escaping (SubscriptionPurchaseEnvironment.Environment) -> Void, openVPN: @escaping () -> Void, openPersonalInformationRemoval: @escaping () -> Void, openIdentityTheftRestoration: @escaping () -> Void) {
        self.openURL = openURL
        self.changePlanOrBilling = changePlanOrBilling
        self.openVPN = openVPN
        self.openPersonalInformationRemoval = openPersonalInformationRemoval
        self.openIdentityTheftRestoration = openIdentityTheftRestoration
    }
}

enum ManageSubscriptionSheet: Identifiable {
    case apple, google

    var id: Self {
        return self
    }
}
