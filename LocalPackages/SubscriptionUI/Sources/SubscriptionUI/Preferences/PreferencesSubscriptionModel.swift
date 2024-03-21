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

import AppKit
import Subscription
import struct Combine.AnyPublisher
import enum Combine.Publishers

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isUserAuthenticated: Bool = false
    @Published var subscriptionDetails: String?
    @Published var subscriptionStatus: Subscription.Status?

    @Published var hasAccessToVPN: Bool = false
    @Published var hasAccessToDBP: Bool = false
    @Published var hasAccessToITR: Bool = false

    private var subscriptionPlatform: Subscription.Platform?

    lazy var sheetModel: SubscriptionAccessModel = makeSubscriptionAccessModel()

    private let accountManager: AccountManager
    private let openURLHandler: (URL) -> Void
    public let userEventHandler: (UserEvent) -> Void
    private let sheetActionHandler: SubscriptionAccessActionHandlers
    private let subscriptionAppGroup: String

    private var fetchSubscriptionDetailsTask: Task<(), Never>?

    private var signInObserver: Any?
    private var signOutObserver: Any?

    public enum UserEvent {
        case openVPN,
             openDB,
             openITR,
             iHaveASubscriptionClick,
             activateAddEmailClick,
             postSubscriptionAddEmailClick,
             addToAnotherDeviceClick,
             addDeviceEnterEmail,
             restorePurchaseStoreClick,
             activeSubscriptionSettingsClick,
             changePlanOrBillingClick,
             removeSubscriptionClick
    }

    lazy var statePublisher: AnyPublisher<PreferencesSubscriptionState, Never> = {
        let isSubscriptionActivePublisher = $subscriptionStatus.map {
            $0 != .expired && $0 != .inactive
        }.eraseToAnyPublisher()

        let hasAnyEntitlementPublisher = Publishers.CombineLatest3($hasAccessToVPN, $hasAccessToDBP, $hasAccessToITR).map {
            return $0 || $1 || $2
        }.eraseToAnyPublisher()

        return Publishers.CombineLatest3($isUserAuthenticated, isSubscriptionActivePublisher, hasAnyEntitlementPublisher)
            .map { isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement in
                switch (isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement) {
                case (false, _, _): return PreferencesSubscriptionState.noSubscription
                case (true, false, _): return PreferencesSubscriptionState.subscriptionExpired
                case (true, true, false): return PreferencesSubscriptionState.subscriptionPendingActivation
                case (true, true, true): return PreferencesSubscriptionState.subscriptionActive
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    public init(openURLHandler: @escaping (URL) -> Void,
                userEventHandler: @escaping (UserEvent) -> Void,
                sheetActionHandler: SubscriptionAccessActionHandlers,
                subscriptionAppGroup: String) {
        self.accountManager = AccountManager(subscriptionAppGroup: subscriptionAppGroup)
        self.openURLHandler = openURLHandler
        self.userEventHandler = userEventHandler
        self.sheetActionHandler = sheetActionHandler
        self.subscriptionAppGroup = subscriptionAppGroup

        self.isUserAuthenticated = accountManager.isUserAuthenticated

        if accountManager.isUserAuthenticated {
            Task {
                await self.updateSubscription(with: .returnCacheDataElseLoad)
                await self.updateAllEntitlement(with: .returnCacheDataElseLoad)
            }
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
            ShareSubscriptionAccessModel(actionHandlers: sheetActionHandler, email: accountManager.email, subscriptionAppGroup: subscriptionAppGroup)
        } else {
            ActivateSubscriptionAccessModel(actionHandlers: sheetActionHandler, shouldShowRestorePurchase: SubscriptionPurchaseEnvironment.current == .appStore)
        }
    }

    private func updateUserAuthenticatedState(_ isUserAuthenticated: Bool) {
        self.isUserAuthenticated = isUserAuthenticated
        sheetModel = makeSubscriptionAccessModel()
    }

    @MainActor
    func purchaseAction() {
        openURLHandler(.subscriptionPurchase)
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
                    self?.changePlanOrBilling(for: .appStore)
                }
            } else {
                return .presentSheet(.apple)
            }
        case .google:
            return .presentSheet(.google)
        case .stripe:
            return .navigateToManageSubscription { [weak self] in
                self?.changePlanOrBilling(for: .stripe)
            }
        default:
            assertionFailure("Missing or unknown subscriptionPlatform")
            return .navigateToManageSubscription { }
        }
    }

    private func changePlanOrBilling(for environment: SubscriptionPurchaseEnvironment.Environment) {
        switch environment {
        case .appStore:
            NSWorkspace.shared.open(.manageSubscriptionsInAppStoreAppURL)
        case .stripe:
            Task {
                guard let accessToken = accountManager.accessToken, let externalID = accountManager.externalID,
                      case let .success(response) = await SubscriptionService.getCustomerPortalURL(accessToken: accessToken, externalID: externalID) else { return }
                guard let customerPortalURL = URL(string: response.customerPortalUrl) else { return }

                openURLHandler(customerPortalURL)
            }
        }
    }

    private func confirmIfSignedInToSameAccount() async -> Bool {
        if #available(macOS 12.0, *) {
            guard let lastTransactionJWSRepresentation = await PurchaseManager.mostRecentTransaction() else { return false }

            switch await AuthService.storeLogin(signature: lastTransactionJWSRepresentation) {
            case .success(let response):
                return response.externalID == accountManager.externalID
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
        userEventHandler(.openVPN)
    }

    @MainActor
    func openPersonalInformationRemoval() {
        userEventHandler(.openDB)
    }

    @MainActor
    func openIdentityTheftRestoration() {
        userEventHandler(.openITR)
    }

    @MainActor
    func openFAQ() {
        openURLHandler(.subscriptionFAQ)
    }

    @MainActor
    func refreshSubscriptionPendingState() {
        if SubscriptionPurchaseEnvironment.current == .appStore {
            if #available(macOS 12.0, *) {
                Task {
                    _ = await AppStoreRestoreFlow.restoreAccountFromPastPurchase(subscriptionAppGroup: subscriptionAppGroup)
                    fetchAndUpdateSubscriptionDetails()
                }
            }
        } else {
            fetchAndUpdateSubscriptionDetails()
        }
    }

    @MainActor
    func fetchAndUpdateSubscriptionDetails() {
        self.isUserAuthenticated = accountManager.isUserAuthenticated

        guard fetchSubscriptionDetailsTask == nil else { return }

        fetchSubscriptionDetailsTask = Task { [weak self] in
            defer {
                self?.fetchSubscriptionDetailsTask = nil
            }

            await self?.updateSubscription(with: .reloadIgnoringLocalCacheData)
            await self?.updateAllEntitlement(with: .reloadIgnoringLocalCacheData)
        }
    }

    @MainActor
    private func updateSubscription(with cachePolicy: SubscriptionService.CachePolicy) async {
        guard let token = accountManager.accessToken else {
            SubscriptionService.signOut()
            return
        }

        switch await SubscriptionService.getSubscription(accessToken: token, cachePolicy: cachePolicy) {
        case .success(let subscription):
            updateDescription(for: subscription.expiresOrRenewsAt, status: subscription.status, period: subscription.billingPeriod)
            subscriptionPlatform = subscription.platform
            subscriptionStatus = subscription.status
        case .failure:
            break
        }
    }

    @MainActor
    private func updateAllEntitlement(with cachePolicy: AccountManager.CachePolicy) async {
        switch await self.accountManager.hasEntitlement(for: .networkProtection, cachePolicy: cachePolicy) {
        case let .success(result):
            hasAccessToVPN = result
        case .failure:
            hasAccessToVPN = false
        }

        switch await self.accountManager.hasEntitlement(for: .dataBrokerProtection, cachePolicy: cachePolicy) {
        case let .success(result):
            hasAccessToDBP = result
        case .failure:
            hasAccessToDBP = false
        }

        switch await self.accountManager.hasEntitlement(for: .identityTheftRestoration, cachePolicy: cachePolicy) {
        case let .success(result):
            hasAccessToITR = result
        case .failure:
            hasAccessToITR = false
        }
    }

    @MainActor
    func updateDescription(for date: Date, status: Subscription.Status, period: Subscription.BillingPeriod) {

        let formattedDate = dateFormatter.string(from: date)

        let billingPeriod: String

        switch period {
        case .monthly: billingPeriod = UserText.monthlySubscriptionBillingPeriod.lowercased()
        case .yearly: billingPeriod = UserText.yearlySubscriptionBillingPeriod.lowercased()
        case .unknown: billingPeriod = ""
        }

        switch status {
        case .autoRenewable:
            self.subscriptionDetails = UserText.preferencesSubscriptionActiveRenewCaption(period: billingPeriod, formattedDate: formattedDate)
        case .expired, .inactive:
            self.subscriptionDetails = UserText.preferencesSubscriptionExpiredCaption(formattedDate: formattedDate)
        default:
            self.subscriptionDetails = UserText.preferencesSubscriptionActiveExpireCaption(period: billingPeriod, formattedDate: formattedDate)
        }
    }

    private var dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        return dateFormatter
    }()
}

enum ManageSubscriptionSheet: Identifiable {
    case apple, google

    var id: Self {
        return self
    }
}

enum PreferencesSubscriptionState: String {
    case noSubscription, subscriptionPendingActivation, subscriptionActive, subscriptionExpired
}
