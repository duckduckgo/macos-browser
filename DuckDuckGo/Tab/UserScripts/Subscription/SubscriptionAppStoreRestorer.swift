//
//  SubscriptionAppStoreRestorer.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import SubscriptionUI
import enum StoreKit.StoreKitError
import PixelKit

@available(macOS 12.0, *)
protocol SubscriptionAppStoreRestorer {
    var uiHandler: SubscriptionUIHandling { get }
    func restoreAppStoreSubscription() async
}

@available(macOS 12.0, *)
struct DefaultSubscriptionAppStoreRestorer: SubscriptionAppStoreRestorer {
    private let subscriptionManager: SubscriptionManager
    private let subscriptionErrorReporter: SubscriptionErrorReporter
//    private let storePurchaseManager: StorePurchaseManager
    private let appStoreRestoreFlow: AppStoreRestoreFlow
    let uiHandler: SubscriptionUIHandling

    public init(subscriptionManager: SubscriptionManager,
                subscriptionErrorReporter: SubscriptionErrorReporter = DefaultSubscriptionErrorReporter(),
//                storePurchaseManager: StorePurchaseManager,
                appStoreRestoreFlow: AppStoreRestoreFlow,
                uiHandler: SubscriptionUIHandling) {
        self.subscriptionManager = subscriptionManager
        self.subscriptionErrorReporter = subscriptionErrorReporter
        self.appStoreRestoreFlow = appStoreRestoreFlow
//        self.storePurchaseManager = storePurchaseManager
        self.uiHandler = uiHandler
    }

    func restoreAppStoreSubscription() async {

        defer {
            Task { @MainActor in
                uiHandler.dismissProgressViewController()
            }
        }

        Task { @MainActor in
            uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)
        }

        do {
            try await subscriptionManager.storePurchaseManager().syncAppleIDAccount()
        } catch {
            switch error as? StoreKitError {
            case .some(.userCancelled):
                return
            default:
                break
            }

            Task { @MainActor in
                uiHandler.show(alertType: .appleIDSyncFailed, text: error.localizedDescription)
            }
        }

        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()

        switch result {
        case .success:
            PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)
        case .failure(let error):
            switch error {
            case .missingAccountOrTransactions: break
            default:
                PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther, frequency: .dailyAndCount)
            }

            switch error {
            case .missingAccountOrTransactions:
                subscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                await showSubscriptionNotFoundAlert()
            case .subscriptionExpired:
                subscriptionErrorReporter.report(subscriptionActivationError: .subscriptionExpired)
                await showSubscriptionInactiveAlert()
            case .pastTransactionAuthenticationError, .failedToObtainAccessToken, .failedToFetchAccountDetails, .failedToFetchSubscriptionDetails:
                subscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                await showSomethingWentWrongAlert()
            }
        }
    }

    // MARK: - UI interactions

    @MainActor
    func showSomethingWentWrongAlert() {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseFailure, frequency: .dailyAndCount)
        uiHandler.show(alertType: .somethingWentWrong)
    }

    @MainActor
    func showSubscriptionNotFoundAlert() {
        uiHandler.show(alertType: .subscriptionNotFound, firstButtonAction: {
            let url = subscriptionManager.url(for: .purchase)
            uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }

    @MainActor
    func showSubscriptionInactiveAlert() {
        uiHandler.show(alertType: .subscriptionInactive, firstButtonAction: {
            let url = subscriptionManager.url(for: .purchase)
            uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }
}
