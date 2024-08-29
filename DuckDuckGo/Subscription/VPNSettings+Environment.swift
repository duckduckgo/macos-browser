//
//  VPNSettings+Environment.swift
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
import NetworkProtection
import Subscription

public extension VPNSettings {

    /// Align VPN environment to the Subscription environment
    func alignTo(subscriptionEnvironment: SubscriptionEnvironment) {
        switch subscriptionEnvironment.serviceEnvironment {
        case .production:
            // Do nothing for a production subscription, as it can be used for both VPN environments.
            break
        case .staging:
            // If using a staging subscription, force the staging VPN environment as it is not compatible with anything else.
            self.selectedEnvironment = .staging
        }
    }
}
