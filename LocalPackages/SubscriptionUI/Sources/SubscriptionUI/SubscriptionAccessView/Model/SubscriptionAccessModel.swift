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
import Subscription

public protocol SubscriptionAccessModel {
    var title: String { get }
    var description: String { get }

    var email: String? { get }
    var emailLabel: String { get }
    var emailDescription: String { get }
    var emailButtonTitle: String { get }

    func handleEmailAction()
}

public protocol PurchaseRestoringSubscriptionAccessModel {
    var shouldShowRestorePurchase: Bool { get }
    var restorePurchaseDescription: String { get }
    var restorePurchaseButtonTitle: String { get }
    func handleRestorePurchaseAction()
}

public final class SubscriptionAccessActionHandlers {
    var restorePurchases: () -> Void
    var openURLHandler: (URL) -> Void
    var uiActionHandler: (PreferencesSubscriptionModel.UserEvent) -> Void

    public init(restorePurchases: @escaping () -> Void, openURLHandler: @escaping (URL) -> Void, uiActionHandler: @escaping (PreferencesSubscriptionModel.UserEvent) -> Void) {
        self.restorePurchases = restorePurchases
        self.openURLHandler = openURLHandler
        self.uiActionHandler = uiActionHandler
    }
}
