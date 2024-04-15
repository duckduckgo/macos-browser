//
//  SubscriptionErrorReporter.swift
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
import Common

enum SubscriptionError: Error {
    case purchaseFailed,
         missingEntitlements,
         failedToGetSubscriptionOptions,
         failedToSetSubscription,
         failedToRestoreFromEmail,
         failedToRestoreFromEmailSubscriptionInactive,
         failedToRestorePastPurchase,
         subscriptionNotFound,
         subscriptionExpired,
         hasActiveSubscription,
         cancelledByUser,
         accountCreationFailed,
         activeSubscriptionAlreadyPresent,
         generalError
}

struct SubscriptionErrorReporter {

    // swiftlint:disable:next cyclomatic_complexity
    static func report(subscriptionActivationError: SubscriptionError) {

        os_log(.error, log: .subscription, "Subscription purchase error: %{public}s", subscriptionActivationError.localizedDescription)

        var isStoreError = false
        var isBackendError = false

        switch subscriptionActivationError {
        case .purchaseFailed:
            isStoreError = true
        case .missingEntitlements:
            isBackendError = true
        case .failedToGetSubscriptionOptions:
            isStoreError = true
        case .failedToSetSubscription:
            isBackendError = true
        case .failedToRestoreFromEmail, .failedToRestoreFromEmailSubscriptionInactive:
            isBackendError = true
        case .failedToRestorePastPurchase:
            isStoreError = true
        case .subscriptionNotFound:
            DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreFailureNotFound, frequency: .dailyAndCount)
            isStoreError = true
        case .subscriptionExpired:
            isStoreError = true
        case .hasActiveSubscription:
            isStoreError = true
            isBackendError = true
        case .cancelledByUser: break
        case .accountCreationFailed:
            DailyPixel.fire(pixel: .privacyProPurchaseFailureAccountNotCreated, frequency: .dailyAndCount)
        case .activeSubscriptionAlreadyPresent: break
        case .generalError: break
        }

        if isStoreError {
            DailyPixel.fire(pixel: .privacyProPurchaseFailureStoreError, frequency: .dailyAndCount)
        }

        if isBackendError {
            DailyPixel.fire(pixel: .privacyProPurchaseFailureBackendError, frequency: .dailyAndCount)
        }
    }
}
