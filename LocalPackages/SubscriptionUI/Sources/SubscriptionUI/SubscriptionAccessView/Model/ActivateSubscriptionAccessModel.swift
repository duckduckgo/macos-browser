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
import Subscription

public final class ActivateSubscriptionAccessModel: SubscriptionAccessModel, PurchaseRestoringSubscriptionAccessModel {
    private var actionHandlers: SubscriptionAccessActionHandlers

    public var title = UserText.activateModalTitle
    public var description = UserText.activateModalDescription(platform: SubscriptionPurchaseEnvironment.current)

    public var email: String?
    public var emailLabel: String { UserText.email }
    public var emailDescription = UserText.activateModalEmailDescription
    public var emailButtonTitle = UserText.enterEmailButton

    public private(set) var shouldShowRestorePurchase: Bool
    public var restorePurchaseDescription = UserText.restorePurchaseDescription
    public var restorePurchaseButtonTitle = UserText.restorePurchaseButton

    public init(actionHandlers: SubscriptionAccessActionHandlers, shouldShowRestorePurchase: Bool) {
        self.actionHandlers = actionHandlers
        self.shouldShowRestorePurchase = shouldShowRestorePurchase
    }

    public func handleEmailAction() {
        actionHandlers.openURLHandler(.activateSubscriptionViaEmail)
        actionHandlers.uiActionHandler(.activateAddEmailClick)
    }

    public func handleRestorePurchaseAction() {
        actionHandlers.restorePurchases()
        actionHandlers.uiActionHandler(.restorePurchaseStoreClick)
    }
}
