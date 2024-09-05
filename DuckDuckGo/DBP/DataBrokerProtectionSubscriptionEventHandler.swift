//
//  DataBrokerProtectionSubscriptionEventHandler.swift
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

import Combine
import Foundation
import Subscription
import DataBrokerProtection
import PixelKit
import Common

final class DataBrokerProtectionSubscriptionEventHandler {

    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private var cancellables = Set<AnyCancellable>()

    init(featureDisabler: DataBrokerProtectionFeatureDisabling,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.featureDisabler = featureDisabler
        self.authenticationManager = authenticationManager
        self.pixelHandler = pixelHandler
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAccountDidSignOut),
                                               name: .accountDidSignOut,
                                               object: nil)

        NotificationCenter.default
            .publisher(for: .entitlementsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.entitlementsDidChange(notification)
            }
            .store(in: &cancellables)
    }

    @objc private func handleAccountDidSignOut() {
        featureDisabler.disableAndDelete()
    }

    private func entitlementsDidChange(_ notification: Notification) {
        guard let entitlements = notification.userInfo?[UserDefaultsCacheKey.subscriptionEntitlements] as? [Entitlement] else {

            assertionFailure("Missing entitlements are truly unexpected")
            return
        }

        let hasEntitlements = entitlements.contains { entitlement in
            entitlement.product == .dataBrokerProtection
        }

        Task {
            await entitlementsDidChange(hasEntitlements: hasEntitlements)
        }
    }

    @MainActor
    private func entitlementsDidChange(hasEntitlements: Bool) async {
        if hasEntitlements {
            pixelHandler.fire(.entitlementCheckValid)
        } else {
            pixelHandler.fire(.entitlementCheckInvalid)
            featureDisabler.disableAndDelete()
        }
    }
}
