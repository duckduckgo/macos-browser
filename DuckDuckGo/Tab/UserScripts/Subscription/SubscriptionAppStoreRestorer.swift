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

import Foundation
import Subscription
import SubscriptionUI
import enum StoreKit.StoreKitError
import PixelKit

@available(macOS 12.0, *)
struct SubscriptionAppStoreRestorer {

    private let subscriptionManager: SubscriptionManager
    @MainActor var window: NSWindow? { WindowControllersManager.shared.lastKeyMainWindowController?.window }
    let subscriptionErrorReporter = SubscriptionErrorReporter()

    public init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func restoreAppStoreSubscription(mainViewController: MainViewController, windowController: MainWindowController) async {

        let progressViewController = await ProgressViewController(title: UserText.restoringSubscriptionTitle)
        defer {
            DispatchQueue.main.async {
                mainViewController.dismiss(progressViewController)
            }
        }

        DispatchQueue.main.async {
            mainViewController.presentAsSheet(progressViewController)
        }

        let syncResult = await subscriptionManager.getStorePurchaseManager().syncAppleIDAccount()

        switch syncResult {
        case .success:
            break
        case .failure(let error):
            switch error as? StoreKitError {
            case .some(.userCancelled):
                return
            default:
                break
            }

            let alert = await NSAlert.appleIDSyncFailedAlert(text: error.localizedDescription)

            switch await alert.runModal() {
            case .alertFirstButtonReturn:
                // Continue button
                break
            default:
                return
            }
        }

        let appStoreRestoreFlow = AppStoreRestoreFlow(subscriptionManager: subscriptionManager)
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
}

@available(macOS 12.0, *)
extension SubscriptionAppStoreRestorer {

    /*
     WARNING: DUPLICATED CODE
     This code will be moved as part of https://app.asana.com/0/0/1207157941206686/f
     */

    // MARK: - UI interactions

    @MainActor
    func showSomethingWentWrongAlert() {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseFailure, frequency: .dailyAndCount)
        guard let window else { return }

        window.show(.somethingWentWrongAlert())
    }

    @MainActor
    func showSubscriptionNotFoundAlert() {
        guard let window else { return }

        window.show(.subscriptionNotFoundAlert(), firstButtonAction: {
            let url = SubscriptionURL.purchase.subscriptionURL(environment: self.subscriptionManager.currentEnvironment.serviceEnvironment)
            WindowControllersManager.shared.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }

    @MainActor
    func showSubscriptionInactiveAlert() {
        guard let window else { return }

        window.show(.subscriptionInactiveAlert(), firstButtonAction: {
            let url = SubscriptionURL.purchase.subscriptionURL(environment: self.subscriptionManager.currentEnvironment.serviceEnvironment)
            WindowControllersManager.shared.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }
}
