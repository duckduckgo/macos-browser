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

public enum AccessChan: String, Identifiable {
    public var id: Self { self }

    case appleID, email, sync
}

public protocol SubscriptionAccessModel {
    var items: [AccessChan] { get }

    func title(for channel: AccessChan) -> String
    func description(for channel: AccessChan) -> String
    func buttonTitle(for channel: AccessChan) -> String?
    func handleAction(for channel: AccessChan)
}

public final class ActivateSubscriptionAccessActionHandlers {
    var openURLHandler: (URL) -> Void
    var goToSyncPreferences: () -> Void

    public init(openURLHandler: @escaping (URL) -> Void, goToSyncPreferences: @escaping () -> Void) {
        self.openURLHandler = openURLHandler
        self.goToSyncPreferences = goToSyncPreferences
    }
}

public final class ActivateSubscriptionAccessModel: SubscriptionAccessModel {

    public var items: [AccessChan] = [.appleID, .email, .sync]
    var actionHandlers: ActivateSubscriptionAccessActionHandlers

    public init(actionHandlers: ActivateSubscriptionAccessActionHandlers) {
        self.actionHandlers = actionHandlers
    }

    public func title(for channel: AccessChan) -> String {
        channel.rawValue
    }

    public func description(for channel: AccessChan) -> String {
        String(repeating: channel.rawValue, count: 22)
    }

    public func buttonTitle(for channel: AccessChan) -> String? {
        switch channel {
        case .appleID:
            return nil
        case .email:
            return "Make \(channel.rawValue)"
        case .sync:
            return "Make \(channel.rawValue)"
        }
    }

    public func handleAction(for channel: AccessChan) {
        print("this is \(channel.rawValue)")

        switch channel {
        case .appleID:
            print("prrr")
        case .email:
            actionHandlers.openURLHandler(URL(string: "https://abrown.duckduckgo.com/subscriptions/activate")!)
        case .sync:
            actionHandlers.goToSyncPreferences()
        }
    }
}
