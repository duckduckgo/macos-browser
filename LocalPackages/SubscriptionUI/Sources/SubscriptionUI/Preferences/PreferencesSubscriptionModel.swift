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
import Networking
import FeatureFlags
import BrowserServicesKit
import os.log

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isUserAuthenticated: Bool = false
    @Published var subscriptionDetails: String?
    @Published var subscriptionStatus: PrivacyProSubscription.Status = .unknown

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

    lazy var sheetModel = SubscriptionAccessViewModel(
        actionHandlers: sheetActionHandler,
        purchasePlatform: subscriptionManager.currentEnvironment.purchasePlatform)

    private let subscriptionManager: SubscriptionManager
    private let openURLHandler: (URL) -> Void
    public let userEventHandler: (UserEvent) -> Void
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    private var fetchSubscriptionDetailsTask: Task<(), Never>?

    private var signInObserver: Any?
    private var signOutObserver: Any?
    private var entitlementsObserver: Any?
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
        let isSubscriptionActivePublisher: AnyPublisher<Bool, Never> = $subscriptionStatus.map {
            let status = $0
            return status != .expired && status != .inactive && status != .unknown
        }.eraseToAnyPublisher()

        let hasAnyEntitlementPublisher = Publishers.CombineLatest3($hasAccessToVPN, $hasAccessToDBP, $hasAccessToITR).map {
            return $0 || $1 || $2
        }.eraseToAnyPublisher()

        return Publishers.CombineLatest3($isUserAuthenticated, isSubscriptionActivePublisher, hasAnyEntitlementPublisher)
            .map { isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement in
                switch (isUserAuthenticated, isSubscriptionActive, hasAnyEntitlement) {
                case (false, _, _): return PreferencesSubscriptionState.noSubscription
                case (true, false, _):
                    switch self.subscriptionStatus {
                    case .expired, .inactive:
                        return PreferencesSubscriptionState.subscriptionExpired
                    default:
                        return PreferencesSubscriptionState.subscriptionPendingActivation
                    }
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
                subscriptionManager: SubscriptionManager,
                featureFlagger: FeatureFlagger) {
        self.subscriptionManager = subscriptionManager
        self.openURLHandler = openURLHandler
        self.userEventHandler = userEventHandler
        self.sheetActionHandler = sheetActionHandler
        self.featureFlagger = featureFlagger
        self.subscriptionStorefrontRegion = currentStorefrontRegion()

        self.isUserAuthenticated = subscriptionManager.isUserAuthenticated

        if self.isUserAuthenticated {
            Task { [weak self] in
                await self?.updateSubscription(cachePolicy: .returnCacheDataElseLoad)
            }

            self.email = subscriptionManager.userEmail
        }

        signInObserver = NotificationCenter.default.addObserver(forName: .accountDidSignIn, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState()
        }

        signOutObserver = NotificationCenter.default.addObserver(forName: .accountDidSignOut, object: nil, queue: .main) { [weak self] _ in
            self?.updateUserAuthenticatedState()
        }

        subscriptionChangeObserver = NotificationCenter.default.addObserver(forName: .subscriptionDidChange, object: nil, queue: .main) { _ in
            Task { [weak self] in
                Logger.general.debug("SubscriptionDidChange notification received")
                await self?.updateSubscription(cachePolicy: .returnCacheDataDontLoad)
            }
        }

        entitlementsObserver = NotificationCenter.default.addObserver(forName: .entitlementsDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { [weak self] in
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

        if let entitlementsObserver {
            NotificationCenter.default.removeObserver(entitlementsObserver)
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

    private func updateUserAuthenticatedState() {
        Task { @MainActor in
            isUserAuthenticated = subscriptionManager.isUserAuthenticated
            email = subscriptionManager.userEmail
        }
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
            return .navigateToManageSubscription { [weak self] in
                self?.changePlanOrBilling(for: .appStore)
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
                do {
                    let customerPortalURL = try await subscriptionManager.getCustomerPortalURL()
                    openURLHandler(customerPortalURL)
                } catch {
                    Logger.general.log("Error getting customer portal URL: \(error, privacy: .public)")
                }
            }
        }
    }

//    private func confirmIfSignedInToSameAccount() async -> Bool {
//        if #available(macOS 12.0, *) {
//            guard let lastTransactionJWSRepresentation = await subscriptionManager.storePurchaseManager().mostRecentTransaction() else { return false }
//            switch await subscriptionManager.authEndpointService.storeLogin(signature: lastTransactionJWSRepresentation) {
//            case .success(let response):
//                return response.externalID == accountManager.externalID
//            case .failure:
//                return false
//            }
//        }
//
//        return false
//    }

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
                    try await subscriptionManager.getTokenContainer(policy: .localValid)
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
        Task {
            await subscriptionManager.signOut(notifyUI: true)
        }
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
                    let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(subscriptionManager: subscriptionManager,
                                                                         storePurchaseManager: subscriptionManager.storePurchaseManager())
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
        updateUserAuthenticatedState()

        guard fetchSubscriptionDetailsTask == nil else { return }

        fetchSubscriptionDetailsTask = Task { [weak self] in
            defer {
                self?.fetchSubscriptionDetailsTask = nil
            }
            await self?.fetchEmail()
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

    private func updateAvailableSubscriptionFeatures() async {
        let features = await subscriptionManager.currentSubscriptionFeatures(forceRefresh: false)
        let vpnFeature = features.first { $0.entitlement == .networkProtection }
        let dbpFeature = features.first { $0.entitlement == .dataBrokerProtection }
        let itrFeature = features.first { $0.entitlement == .identityTheftRestoration }
        let itrgFeature = features.first { $0.entitlement == .identityTheftRestorationGlobal }

        Task { @MainActor in
            // Should show
            shouldShowVPN = vpnFeature != nil
            shouldShowDBP = dbpFeature != nil
            shouldShowITR = itrFeature != nil || itrgFeature != nil

            // is active/enabled
            hasAccessToVPN = vpnFeature?.enabled ?? false
            hasAccessToDBP = dbpFeature?.enabled ?? false
            hasAccessToITR = itrFeature?.enabled ?? false || itrgFeature?.enabled ?? false
        }
    }

    @MainActor func fetchEmail() async {
        let tokenContainer = try? await subscriptionManager.getTokenContainer(policy: .local)
        email = tokenContainer?.decodedAccessToken.email
    }

    private func updateSubscription(cachePolicy: SubscriptionCachePolicy) async {
        updateUserAuthenticatedState()

        if isUserAuthenticated {
            do {
                let subscription = try await subscriptionManager.getSubscription(cachePolicy: cachePolicy)
                Task { @MainActor in
                    updateDescription(for: subscription.expiresOrRenewsAt, status: subscription.status, period: subscription.billingPeriod)
                    subscriptionPlatform = subscription.platform
                    subscriptionStatus = subscription.status
                }
            } catch {
                Task { @MainActor in
                    subscriptionPlatform = .unknown
                    subscriptionStatus = .unknown
                }
            }
            await self.updateAvailableSubscriptionFeatures()
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
#if DEBUG
        dateFormatter.timeStyle = .medium
#else
        dateFormatter.timeStyle = .none
#endif
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
