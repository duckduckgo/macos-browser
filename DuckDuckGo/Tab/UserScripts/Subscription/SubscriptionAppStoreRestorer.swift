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

@available(macOS 12.0, *)
struct SubscriptionAppStoreRestorer {

    static func restoreAppStoreSubscription(mainViewController: MainViewController, windowController: MainWindowController) async {

        let progressViewController = await ProgressViewController(title: UserText.restoringSubscriptionTitle)
        defer {
            DispatchQueue.main.async {
                mainViewController.dismiss(progressViewController)
            }
        }

        DispatchQueue.main.async {
            mainViewController.presentAsSheet(progressViewController)
        }

        guard case .success = await PurchaseManager.shared.syncAppleIDAccount() else {
            return
        }

        let result = await AppStoreRestoreFlow.restoreAccountFromPastPurchase(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))

        switch result {
        case .success:
            DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)

        case .failure(let error):
            switch error {
            case .missingAccountOrTransactions: break
            default:
                DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreFailureOther, frequency: .dailyAndCount)
            }

            switch error {
            case .missingAccountOrTransactions:
                SubscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                await windowController.showSubscriptionNotFoundAlert()
            case .subscriptionExpired:
                SubscriptionErrorReporter.report(subscriptionActivationError: .subscriptionExpired)
                await windowController.showSubscriptionInactiveAlert()
            case .pastTransactionAuthenticationError, .failedToObtainAccessToken, .failedToFetchAccountDetails, .failedToFetchSubscriptionDetails:
                SubscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                await windowController.showSomethingWentWrongAlert()
            }
        }
    }
}
