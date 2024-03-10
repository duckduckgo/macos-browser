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

public final class PreferencesSubscriptionModel: ObservableObject {

    @Published var isUserAuthenticated: Bool = false
    @Published var subscriptionDetails: String?

    @Published var hasAccessToVPN: Bool = false
    @Published var hasAccessToDBP: Bool = false
    @Published var hasAccessToITR: Bool = false

    private var subscriptionPlatform: Subscription.Platform?

    lazy var sheetModel: SubscriptionAccessModel = makeSubscriptionAccessModel()

    private let accountManager: AccountManager
    private let openURLHandler: (URL) -> Void
    private let openVPNHandler: () -> Void
    private let openDBPHandler: () -> Void
    private let openITRHandler: () -> Void
    private let sheetActionHandler: SubscriptionAccessActionHandlers
    private let subscriptionAppGroup: String

    private var fetchSubscriptionDetailsTask: Task<(), Never>?

    private var signInObserver: Any?
    private var signOutObserver: Any?

    public init(openURLHandler: @escaping (URL) -> Void,
                openVPNHandler: @escaping () -> Void,
                openDBPHandler: @escaping () -> Void,
                openITRHandler: @escaping () -> Void,
                sheetActionHandler: SubscriptionAccessActionHandlers,
                subscriptionAppGroup: String) {
        self.accountManager = AccountManager(subscriptionAppGroup: subscriptionAppGroup)
        self.openURLHandler = openURLHandler
        self.openVPNHandler = openVPNHandler
        self.openDBPHandler = openDBPHandler
        self.openITRHandler = openITRHandler
        self.sheetActionHandler = sheetActionHandler
        self.subscriptionAppGroup = subscriptionAppGroup

        self.isUserAuthenticated = accountManager.isUserAuthenticated
        
        if let token = accountManager.accessToken {
            Task {
                let subscriptionResult = await SubscriptionService.getSubscription(accessToken: token)
                if case .success(let subscription) = subscriptionResult {
                    self.updateDescription(for: subscription.expiresOrRenewsAt)
                }
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
        openVPNHandler()
    }

    @MainActor
    func openPersonalInformationRemoval() {
        openDBPHandler()
    }

    @MainActor
    func openIdentityTheftRestoration() {
        openITRHandler()
    }

    @MainActor
    func openFAQ() {
        openURLHandler(.subscriptionFAQ)
    }

    // swiftlint:disable cyclomatic_complexity
    @MainActor
    func fetchAndUpdateSubscriptionDetails() {
        guard fetchSubscriptionDetailsTask == nil else { return }

        fetchSubscriptionDetailsTask = Task { [weak self] in
            defer {
                self?.fetchSubscriptionDetailsTask = nil
            }

            guard let token = self?.accountManager.accessToken else { return }
            
                let subscriptionResult = await SubscriptionService.getSubscription(accessToken: token)
                
                if case .success(let subscription) = subscriptionResult {
                    self?.updateDescription(for: subscription.expiresOrRenewsAt)
                    
                    if subscription.expiresOrRenewsAt.timeIntervalSinceNow < 0 {
                        self?.hasAccessToVPN = false
                        self?.hasAccessToDBP = false
                        self?.hasAccessToITR = false
                        
                        if !subscription.isActive {
                            self?.accountManager.signOut()
                            return
                        }
                        
                        self?.updateDescription(for: subscription.expiresOrRenewsAt)
                        self?.subscriptionPlatform = subscription.platform
                        
                    }
                } else {
                    self?.accountManager.signOut()
                }
           
            if let self {
                switch await self.accountManager.hasEntitlement(for: .networkProtection) {
                case let .success(result):
                    hasAccessToVPN = result
                case .failure:
                    hasAccessToVPN = false
                }

                switch await self.accountManager.hasEntitlement(for: .dataBrokerProtection) {
                case let .success(result):
                    hasAccessToDBP = result
                case .failure:
                    hasAccessToDBP = false
                }

                switch await self.accountManager.hasEntitlement(for: .identityTheftRestoration) {
                case let .success(result):
                    hasAccessToITR = result
                case .failure:
                    hasAccessToITR = false
                }
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

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

enum ManageSubscriptionSheet: Identifiable {
    case apple, google

    var id: Self {
        return self
    }
}
