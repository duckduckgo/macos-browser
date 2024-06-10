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
#if DBP

import Foundation
import Subscription
import DataBrokerProtection
import PixelKit
import Common

final class DataBrokerProtectionSubscriptionEventHandler {

    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(entitlementsDidChange),
                                               name: .entitlementsDidChange,
                                               object: nil)
    }

    @objc private func handleAccountDidSignOut() {
        featureDisabler.disableAndDelete()
    }

    @objc private func entitlementsDidChange() {
        Task { @MainActor in
            do {
                if try await authenticationManager.hasValidEntitlement() {
                    pixelHandler.fire(.entitlementCheckValid)
                } else {
                    pixelHandler.fire(.entitlementCheckInvalid)
                    featureDisabler.disableAndDelete()
                }
            } catch {
                /// We don't want to disable the agent in case of an error while checking for entitlements.
                /// Since this is a destructive action, the only situation that should cause the data to be deleted and the agent to be removed is .success(false)
                pixelHandler.fire(.entitlementCheckError)
                assertionFailure("Error validating entitlement \(error)")
            }
        }
    }
}

#endif
