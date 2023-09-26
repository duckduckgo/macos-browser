//
//  SubscriptionAccessModel.swift
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

public enum AccessChan: String, CaseIterable, Identifiable {
    public var id: Self { self }

    case appleID, email, sync

    var title: String {
        switch self {
        case .appleID:
            return "Apple ID"
        case .email:
            return "Email"
        case .sync:
            return "Sync"
        }
    }

    var iconName: String {
        switch self {
        case .appleID:
            return "apple-id-icon"
        case .email:
            return "email-icon"
        case .sync:
            return "sync-icon"
        }
    }
}

public protocol SubscriptionAccessModel {
    var items: [AccessChan] { get }

    var title: String { get }
    var description: String { get }

    func descriptionHeader(for channel: AccessChan) -> String?
    func description(for channel: AccessChan) -> String
    func buttonTitle(for channel: AccessChan) -> String?
    func handleAction(for channel: AccessChan)
}

extension SubscriptionAccessModel {
    public var items: [AccessChan] { AccessChan.allCases }

    public func descriptionHeader(for channel: AccessChan) -> String? { nil }
}

public final class ActivateSubscriptionAccessModel: SubscriptionAccessModel {
    public var actionHandlers: SubscriptionAccessActionHandlers
    public var title = "Activate your subscription on this device"
    public var description = "Access your Privacy Pro subscription on this device via Sync, Apple ID or an email address."

    public init(actionHandlers: SubscriptionAccessActionHandlers) {
        self.actionHandlers = actionHandlers
    }

    public func description(for channel: AccessChan) -> String {
        switch channel {
        case .appleID:
            return "Your subscription is automatically available on any device signed in to the same Apple ID."
        case .email:
            return "Use your email to access your subscription on this device."
        case .sync:
            return "Privacy Pro is automatically available on your Synced devices. Manage your synced devices in Sync settings."
        }
    }

    public func buttonTitle(for channel: AccessChan) -> String? {
        switch channel {
        case .appleID:
            return "Restore Purchases"
        case .email:
            return "Enter Email"
        case .sync:
            return "Go to Sync Settings"
        }
    }

    public func handleAction(for channel: AccessChan) {
        switch channel {
        case .appleID:
            actionHandlers.restorePurchases()
        case .email:
            actionHandlers.openURLHandler(URL(string: "https://abrown.duckduckgo.com/subscriptions/activate")!)
        case .sync:
            actionHandlers.goToSyncPreferences()
        }
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

    public func descriptionHeader(for channel: AccessChan) -> String? {
        hasEmail && channel == .email ? email : nil
    }

    public func description(for channel: AccessChan) -> String {
        switch channel {
        case .appleID:
            return "Your subscription is automatically available on any device signed in to the same Apple ID."
        case .email:
            return hasEmail ? "You can use this email to activate your subscription on your other devices." : "Add an email address to access your subscription on your other devices. We’ll only use this address to verify your subscription."
        case .sync:
            return "Privacy Pro is automatically available on your Synced devices. Manage your synced devices in Sync settings."
        }
    }

    public func buttonTitle(for channel: AccessChan) -> String? {
        switch channel {
        case .appleID:
            return nil
        case .email:
            return hasEmail ? "Manage" : "Enter Email"
        case .sync:
            return "Go to Sync Settings"
        }
    }

    public func handleAction(for channel: AccessChan) {
        switch channel {
        case .appleID:
            actionHandlers.restorePurchases()
        case .email:
            let manageEmailURL = URL(string: "https://abrown.duckduckgo.com/subscriptions/manage")!
            let addEmailURL = URL(string: "https://abrown.duckduckgo.com/subscriptions/add-email")!
            actionHandlers.openURLHandler(hasEmail ? manageEmailURL : addEmailURL)
        case .sync:
            actionHandlers.goToSyncPreferences()
        }
    }
}

public final class SubscriptionAccessActionHandlers {
    var restorePurchases: () -> Void
    var openURLHandler: (URL) -> Void
    var goToSyncPreferences: () -> Void

    public init(restorePurchases: @escaping () -> Void, openURLHandler: @escaping (URL) -> Void, goToSyncPreferences: @escaping () -> Void) {
        self.restorePurchases = restorePurchases
        self.openURLHandler = openURLHandler
        self.goToSyncPreferences = goToSyncPreferences
    }
}
