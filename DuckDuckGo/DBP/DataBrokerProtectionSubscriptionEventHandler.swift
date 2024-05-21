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

final class DataBrokerProtectionSubscriptionEventHandler {
    private let featureDisabler: DataBrokerProtectionFeatureDisabling

    init(featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler()) {
        self.featureDisabler = featureDisabler
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .entitlementsDidChange, object: nil)
    }

    @objc private func handleAccountDidSignOut() {
        featureDisabler.disableAndDelete()
    }

    @objc private func entitlementsDidChange() {
        #warning("Validate if valid and delete if necessary after sending pixels")
    }
}

#endif
