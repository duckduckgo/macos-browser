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
import FeatureFlags
import BrowserServicesKit

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isUserAuthenticated: Bool = false
    @Published var subscriptionDetails: String?
    @Published var subscriptionStatus: PrivacyProSubscription.Status?

    @Published var subscriptionStorefrontRegion: SubscriptionRegion = .usa

    @Published var shouldShowVPN: Bool = false
    @Published var shouldShowDBP: Bool = false
    @Published var shouldShowITR: Bool = false

    @Published var hasAccessToVPN: Bool = false
    @Published var hasAccessToDBP: Bool = false
    @Published var hasAccessToITR: Bool = false

    @Published var email: String?
    var hasEmail: Bool { !(email?.isEmpty ?? true) }

    let featureFlagger: FeatureFlagger

    private var subscriptionPlatform: PrivacyProSubscription.Platform?

    lazy var sheetModel = SubscriptionAccessViewModel(actionHandlers: sheetActionHandler,
        purchasePlatform: subscriptionManager.currentEnvironment.purchasePlatform)

    private let subscriptionManager: SubscriptionManager
    private var accountManager: AccountManager {
        subscriptionManager.accountManager
    }
    private let openURLHandler: (URL) -> Void
    public let userEventHandler: (UserEvent) -> Void
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    private var fetchSubscriptionDetailsTask: Task<(), Never>?

    private var signInObserver: Any?
    private var signOutObserver: Any?
    private var subscriptionChangeObserver: Any?

    public enum UserEvent {
        case openVPN,
             openDB,
             openITR,
             openFeedback,
             iHaveASubscriptionClick,
             activateAddEmailClick,
             postSubscriptionAddEmailClick,
             addDeviceEnterEmail,
             restorePurchaseStoreClick,
             activeSubscriptionSettingsClick,
             changePlanOrBillingClick,
             removeSubscriptionClick
    }

    lazy var statePublisher: AnyPublisher<PreferencesSubscriptionState, Never> = {
        let isSubscriptionActivePublisher: AnyPublisher<Bool?, Never> = $subscriptionStatus.map {
            guard let status = $0 else { return nil}
            return status != .expired && status != .inactive
        }.eraseToAnyPublisher()

        let hasAnyEntitlementPublisher = Publishers.CombineLatest3($hasAccessToVPN, $hasAccessToDBP, $hasAccessToITR).map {
            return $0 || $1 || $2
        }.eraseToAnyPublisher()

        return Publishers.CombineLatest3($isUserAuthenticated, isSubscriptionActivePublisher, hasAnyEntitlementPublisher)
            .map { isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement in
                switch (isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement) {
                case (false, _, _): return PreferencesSubscriptionState.noSubscription
                case (true, .some(false), _): return PreferencesSubscriptionState.subscriptionExpired
                case (true, nil, _): return PreferencesSubscriptionState.subscriptionPendingActivation
                case (true, .some(true), false): return PreferencesSubscriptionState.subscriptionPendingActivation
                case (true, .some(true), true): return PreferencesSubscriptionState.subscriptionActive
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    public init(openURLHandler: @escaping (URL) -> Void,
                userEventHandler: @escaping (UserEvent) -> Void,
                sheetActionHandler: SubscriptionAccessActionHandlers,
                subscriptionManager: SubscriptionManager,
                featureFlagger: FeatureFlagger) {
        self.subscriptionManager = subscriptionManager
        self.openURLHandler = openURLHandler
        self.userEventHandler = userEventHandler
        self.sheetActionHandler = sheetActionHandler
        self.featureFlagger = featureFlagger
        self.subscriptionStorefrontRegion = currentStorefrontRegion()

        self.isUserAuthenticated = accountManager.isUserAuthenticated

        if accountManager.isUserAuthenticated {
            Task {
                await self.updateSubscription(cachePolicy: .returnCacheDataElseLoad)
                await self.updateAvailableSubscriptionFeatures()
                await self.loadCachedEntitlements()
            }

            self.email = accountManager.email
        }

        signInObserver = NotificationCenter.default.addObserver(forName: .accountDidSignIn, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState(true)
        }

        signOutObserver = NotificationCenter.default.addObserver(forName: .accountDidSignOut, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState(false)
        }

        subscriptionChangeObserver = NotificationCenter.default.addObserver(forName: .subscriptionDidChange, object: nil, queue: .main) { _ in
            Task { [weak self] in
                await self?.updateSubscription(cachePolicy: .returnCacheDataDontLoad)
                await self?.updateAvailableSubscriptionFeatures()
            }
        }
    }

    deinit {
        if let signInObserver {
            NotificationCenter.default.removeObserver(signInObserver)
        }

        if let signOutObserver {
            NotificationCenter.default.removeObserver(signOutObserver)
        }

        if let subscriptionChangeObserver {
            NotificationCenter.default.removeObserver(subscriptionChangeObserver)
        }
    }

    @MainActor
    func didAppear() {
        if isUserAuthenticated {
            userEventHandler(.activeSubscriptionSettingsClick)
            fetchAndUpdateSubscriptionDetails()
        } else {
            self.subscriptionStorefrontRegion = currentStorefrontRegion()
        }
    }

    private func updateUserAuthenticatedState(_ isUserAuthenticated: Bool) {
        self.isUserAuthenticated = isUserAuthenticated
        self.email = accountManager.email
    }

    @MainActor
    func purchaseAction() {
        openURLHandler(subscriptionManager.url(for: .purchase))
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

    private func changePlanOrBilling(for environment: SubscriptionEnvironment.PurchasePlatform) {
        switch environment {
        case .appStore:
            NSWorkspace.shared.open(subscriptionManager.url(for: .manageSubscriptionsInAppStore))
        case .stripe:
            Task {
                guard let accessToken = accountManager.accessToken, let externalID = accountManager.externalID,
                      case let .success(response) = await subscriptionManager.subscriptionEndpointService.getCustomerPortalURL(accessToken: accessToken, externalID: externalID) else { return }
                guard let customerPortalURL = URL(string: response.customerPortalUrl) else { return }

                openURLHandler(customerPortalURL)
            }
        }
    }

    private func confirmIfSignedInToSameAccount() async -> Bool {
        if #available(macOS 12.0, *) {
            guard let lastTransactionJWSRepresentation = await subscriptionManager.storePurchaseManager().mostRecentTransaction() else { return false }
            switch await subscriptionManager.authEndpointService.storeLogin(signature: lastTransactionJWSRepresentation) {
            case .success(let response):
                return response.externalID == accountManager.externalID
            case .failure:
                return false
            }
        }

        return false
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
    func openLearnMore(_ url: URL) {
        openURLHandler(url)
    }

    @MainActor
    func addEmailAction() {
        handleEmailAction(type: .add)
    }

    @MainActor
    func editEmailAction() {
        handleEmailAction(type: .edit)
    }

    private enum SubscriptionEmailActionType {
        case add, edit
    }
    private func handleEmailAction(type: SubscriptionEmailActionType) {
        let eventType: UserEvent
        let url: URL

        switch type {
        case .add:
            eventType = .addDeviceEnterEmail
            url = subscriptionManager.url(for: .addEmail)
        case .edit:
            eventType = .postSubscriptionAddEmailClick
            url = subscriptionManager.url(for: .manageEmail)
        }

        Task {
            if subscriptionManager.currentEnvironment.purchasePlatform == .appStore {
                if #available(macOS 12.0, iOS 15.0, *) {
                    let appStoreAccountManagementFlow = DefaultAppStoreAccountManagementFlow(authEndpointService: subscriptionManager.authEndpointService,
                                                                                             storePurchaseManager: subscriptionManager.storePurchaseManager(),
                                                                                             accountManager: subscriptionManager.accountManager)
                    await appStoreAccountManagementFlow.refreshAuthTokenIfNeeded()
                }
            }

            Task { @MainActor in
                userEventHandler(eventType)
                openURLHandler(url)
            }
        }
    }

    @MainActor
    func removeFromThisDeviceAction() {
        userEventHandler(.removeSubscriptionClick)
        accountManager.signOut()
    }

    @MainActor
    func openFAQ() {
        openURLHandler(subscriptionManager.url(for: .faq))
    }

    @MainActor
    func openUnifiedFeedbackForm() {
        userEventHandler(.openFeedback)
    }

    @MainActor
    func openPrivacyPolicy() {
        openURLHandler(URL(string: "https://duckduckgo.com/pro/privacy-terms")!)
    }

    @MainActor
    func refreshSubscriptionPendingState() {
        if subscriptionManager.currentEnvironment.purchasePlatform == .appStore {
            if #available(macOS 12.0, *) {
                Task {
                    let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(accountManager: subscriptionManager.accountManager,
                                                                         storePurchaseManager: subscriptionManager.storePurchaseManager(),
                                                                         subscriptionEndpointService: subscriptionManager.subscriptionEndpointService,
                                                                         authEndpointService: subscriptionManager.authEndpointService)
                    await appStoreRestoreFlow.restoreAccountFromPastPurchase()
                    fetchAndUpdateSubscriptionDetails()
                }
            }
        } else {
            fetchAndUpdateSubscriptionDetails()
        }
    }

    @MainActor
    private func fetchAndUpdateSubscriptionDetails() {
        self.isUserAuthenticated = accountManager.isUserAuthenticated

        guard fetchSubscriptionDetailsTask == nil else { return }

        fetchSubscriptionDetailsTask = Task { [weak self] in
            defer {
                self?.fetchSubscriptionDetailsTask = nil
            }

            await self?.fetchEmailAndRemoteEntitlements()
            await self?.updateSubscription(cachePolicy: .reloadIgnoringLocalCacheData)
        }
    }

    private func currentStorefrontRegion() -> SubscriptionRegion {
        var region: SubscriptionRegion?

        switch subscriptionManager.currentEnvironment.purchasePlatform {
        case .appStore:
            if #available(macOS 12.0, *) {
                region = subscriptionManager.storePurchaseManager().currentStorefrontRegion
            }
        case .stripe:
            region = .usa
        }

        return region ?? .usa
    }

    @MainActor
    private func updateAvailableSubscriptionFeatures() async {
        let features = await currentSubscriptionFeatures()

        shouldShowVPN = features.contains(.networkProtection)
        shouldShowDBP = features.contains(.dataBrokerProtection)
        shouldShowITR = features.contains(.identityTheftRestoration) || features.contains(.identityTheftRestorationGlobal)
    }

    private func currentSubscriptionFeatures() async -> [Entitlement.ProductName] {
        if subscriptionManager.currentEnvironment.purchasePlatform == .appStore {
            return await subscriptionManager.currentSubscriptionFeatures()
        } else {
            return [.networkProtection, .dataBrokerProtection, .identityTheftRestoration]
        }
    }

    @MainActor
    private func loadCachedEntitlements() async {
        switch await self.accountManager.hasEntitlement(forProductName: .networkProtection, cachePolicy: .returnCacheDataDontLoad) {
        case let .success(result):
            hasAccessToVPN = result
        case .failure:
            hasAccessToVPN = false
        }

        switch await self.accountManager.hasEntitlement(forProductName: .dataBrokerProtection, cachePolicy: .returnCacheDataDontLoad) {
        case let .success(result):
            hasAccessToDBP = result
        case .failure:
            hasAccessToDBP = false
        }

        var hasITR = false
        switch await self.accountManager.hasEntitlement(forProductName: .identityTheftRestoration, cachePolicy: .returnCacheDataDontLoad) {
        case let .success(result):
            hasITR = result
        case .failure:
            hasITR = false
        }

        var hasITRGlobal = false
        switch await self.accountManager.hasEntitlement(forProductName: .identityTheftRestorationGlobal, cachePolicy: .returnCacheDataDontLoad) {
        case let .success(result):
            hasITRGlobal = result
        case .failure:
            hasITRGlobal = false
        }

        hasAccessToITR = hasITR || hasITRGlobal
    }

    @MainActor func fetchEmailAndRemoteEntitlements() async {
        guard let accessToken = accountManager.accessToken else { return }

        if case let .success(response) = await subscriptionManager.authEndpointService.validateToken(accessToken: accessToken) {
            if accountManager.email != response.account.email {
                email = response.account.email
                accountManager.storeAccount(token: accessToken, email: response.account.email, externalID: response.account.externalID)
            }

            let entitlements = response.account.entitlements.compactMap { $0.product }
            hasAccessToVPN = entitlements.contains(.networkProtection)
            hasAccessToDBP = entitlements.contains(.dataBrokerProtection)
            hasAccessToITR = entitlements.contains(.identityTheftRestoration) || entitlements.contains(.identityTheftRestorationGlobal)
            accountManager.updateCache(with: response.account.entitlements)
        }
    }

    @MainActor
    private func updateSubscription(cachePolicy: APICachePolicy) async {
        guard let token = accountManager.accessToken else {
            subscriptionManager.subscriptionEndpointService.signOut()
            return
        }

        switch await subscriptionManager.subscriptionEndpointService.getSubscription(accessToken: token, cachePolicy: cachePolicy) {
        case .success(let subscription):
            updateDescription(for: subscription.expiresOrRenewsAt, status: subscription.status, period: subscription.billingPeriod)
            subscriptionPlatform = subscription.platform
            subscriptionStatus = subscription.status
        case .failure:
            break
        }
    }

    @MainActor
    func updateDescription(for date: Date, status: PrivacyProSubscription.Status, period: PrivacyProSubscription.BillingPeriod) {
        let formattedDate = dateFormatter.string(from: date)

        switch status {
        case .autoRenewable:
            self.subscriptionDetails = UserText.preferencesSubscriptionRenewingCaption(billingPeriod: period, formattedDate: formattedDate)
        case .expired, .inactive:
            self.subscriptionDetails = UserText.preferencesSubscriptionExpiredCaption(formattedDate: formattedDate)
        default:
            self.subscriptionDetails = UserText.preferencesSubscriptionExpiringCaption(billingPeriod: period, formattedDate: formattedDate)
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
