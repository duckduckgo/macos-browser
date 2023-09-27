//
//  ShareSubscriptionAccessModel.swift
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

    static var addEmailToSubscription: URL {
        URL(string: "https://abrown.duckduckgo.com/subscriptions/add-email")!
    }

    static var manageSubscriptionEmail: URL {
        URL(string: "https://abrown.duckduckgo.com/subscriptions/manage")!
    }
}

public final class ShareSubscriptionAccessModel: SubscriptionAccessModel {
    public var actionHandlers: SubscriptionAccessActionHandlers
    public var title = "Use your subscription on all your devices"
    public var description = "Access your Privacy Pro subscription on any of your devices via Sync, Apple ID or by adding an email address."
    private var email: String?

    private var hasEmail: Bool { !(email?.isEmpty ?? true) }

    public init(actionHandlers: SubscriptionAccessActionHandlers, email: String?) {
        self.actionHandlers = actionHandlers
        self.email = email
    }

    public func descriptionHeader(for channel: AccessChannel) -> String? {
        hasEmail && channel == .email ? email : nil
    }

    public func description(for channel: AccessChannel) -> String {
        switch channel {
        case .appleID:
            return "Your subscription is automatically available on any device signed in to the same Apple ID."
        case .email:
            return hasEmail ? "You can use this email to activate your subscription on your other devices." : "Add an email address to access your subscription on your other devices. We’ll only use this address to verify your subscription."
        case .sync:
            return "Privacy Pro is automatically available on your Synced devices. Manage your synced devices in Sync settings."
        }
    }

    public func buttonTitle(for channel: AccessChannel) -> String? {
        switch channel {
        case .appleID:
            return nil
        case .email:
            return hasEmail ? "Manage" : "Enter Email"
        case .sync:
            return "Go to Sync Settings"
        }
    }

    public func handleAction(for channel: AccessChannel) {
        switch channel {
        case .appleID:
            actionHandlers.restorePurchases()
        case .email:
            actionHandlers.openURLHandler(hasEmail ? .manageSubscriptionEmail : .addEmailToSubscription)
        case .sync:
            actionHandlers.goToSyncPreferences()
        }
    }
}
