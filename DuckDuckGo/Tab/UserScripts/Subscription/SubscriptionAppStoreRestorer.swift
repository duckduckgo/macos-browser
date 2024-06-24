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
struct SubscriptionAppStoreRestorer {

    private let subscriptionManager: SubscriptionManager
    @MainActor var window: NSWindow? { WindowControllersManager.shared.lastKeyMainWindowController?.window }
    let subscriptionErrorReporter = SubscriptionErrorReporter()
    let uiHandler: SubscriptionUIHandling

    public init(subscriptionManager: SubscriptionManager,
                uiHandler: SubscriptionUIHandling) {
        self.subscriptionManager = subscriptionManager
        self.uiHandler = uiHandler
    }

    func restoreAppStoreSubscription() async {
        await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)

        do {
            try await subscriptionManager.storePurchaseManager().syncAppleIDAccount()
            await continueRestore()
        } catch {
            await uiHandler.dismissProgressViewController()

            switch error as? StoreKitError {
            case .some(.userCancelled):
                break
            default:
                let alertResponse = await uiHandler.show(alertType: .appleIDSyncFailed, text: error.localizedDescription)
                if alertResponse == .alertFirstButtonReturn {
                    await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)
                    await continueRestore()
                }
            }
        }
    }

    private func continueRestore() async {
        let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(subscriptionManager: subscriptionManager)
        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
        await uiHandler.dismissProgressViewController()
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

    func showSomethingWentWrongAlert() async {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseFailure, frequency: .dailyAndCount)
        await uiHandler.show(alertType: .somethingWentWrong)
    }

    func showSubscriptionNotFoundAlert() async {
        switch await uiHandler.show(alertType: .subscriptionNotFound) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }

    func showSubscriptionInactiveAlert() async {
        switch await uiHandler.show(alertType: .subscriptionInactive) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }
}
