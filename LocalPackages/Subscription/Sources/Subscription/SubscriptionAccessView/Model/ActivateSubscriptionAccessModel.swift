//
//  ActivateSubscriptionAccessModel.swift
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

import Foundation

extension URL {

    static var activateSubscriptionViaEmail: URL {
        URL(string: "https://abrown.duckduckgo.com/subscriptions/activate")!
    }
}

public final class ActivateSubscriptionAccessModel: SubscriptionAccessModel {
    public var actionHandlers: SubscriptionAccessActionHandlers
    public var title = "Activate your subscription on this device"
    public var description = "Access your Privacy Pro subscription on this device via Sync, Apple ID or an email address."

    public init(actionHandlers: SubscriptionAccessActionHandlers) {
        self.actionHandlers = actionHandlers
    }

    public func description(for channel: AccessChannel) -> String {
        switch channel {
        case .appleID:
            return "Your subscription is automatically available on any device signed in to the same Apple ID."
        case .email:
            return "Use your email to access your subscription on this device."
        case .sync:
            return "Privacy Pro is automatically available on your Synced devices. Manage your synced devices in Sync settings."
        }
    }

    public func buttonTitle(for channel: AccessChannel) -> String? {
        switch channel {
        case .appleID:
            return "Restore Purchases"
        case .email:
            return "Enter Email"
        case .sync:
            return "Go to Sync Settings"
        }
    }

    public func handleAction(for channel: AccessChannel) {
        switch channel {
        case .appleID:
            actionHandlers.restorePurchases()
        case .email:
            actionHandlers.openURLHandler(.activateSubscriptionViaEmail)
        case .sync:
            actionHandlers.goToSyncPreferences()
        }
    }
}
