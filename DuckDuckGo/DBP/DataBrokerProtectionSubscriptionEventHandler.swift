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
#if DBP && SUBSCRIPTION

import Foundation
import Subscription
import DataBrokerProtection

final class DataBrokerProtectionSubscriptionEventHandler {

    private let accountManager: Subscription.AccountManaging
    private let authRepository: AuthenticationRepository

    init(accountManager: Subscription.AccountManaging = Subscription.AccountManager(),
         authRepository: AuthenticationRepository = KeychainAuthenticationData()) {
        self.accountManager = accountManager
        self.authRepository = authRepository
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
    }

    @objc private func handleAccountDidSignIn() {
        guard let token = accountManager.accessToken else {
            Pixel.fire(.dataBrokerProtectionErrorWhenFetchingSubscriptionAuthTokenAfterSignIn)
            assertionFailure("[DBP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }

        authRepository.save(accessToken: token)
    }

    @objc private func handleAccountDidSignOut() {
        // Going to be defined here: https://app.asana.com/0/1204006570077678/1206206961074916/f
    }
}

#endif
