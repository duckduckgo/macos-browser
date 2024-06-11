//
//  SubscriptionUIHandling.swift
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
import SubscriptionUI

@MainActor
protocol SubscriptionUIHandling {
    
    // MARK: ProgressViewController
    func presentProgressViewController(withTitle: String)
    func dismissProgressViewController()
    func updateProgressViewController(title: String)

    // MARK: SubscriptionAccessViewController
    func presentSubscriptionAccessViewController(handler: SubscriptionAccessActionHandling, message: WKScriptMessage)

    // MARK: Alerts
    func show(alertType: SubscriptionAlertType)
    func show(alertType: SubscriptionAlertType, firstButtonAction: (() -> Void)?)
    func show(alertType: SubscriptionAlertType, text: String?)

    // MARK: Tab
    func showTab(with content: Tab.TabContent)
}

enum SubscriptionAlertType {
    case somethingWentWrong
    case subscriptionNotFound
    case subscriptionInactive
    case subscriptionFound
    case appleIDSyncFailed
}

typealias SubscriptionAccessActionHandlingEvent = PreferencesSubscriptionModel.UserEvent

protocol SubscriptionAccessActionHandling {
    func subscriptionAccessActionRestorePurchases(message: WKScriptMessage)
    func subscriptionAccessActionOpenURLHandler(url: URL)
    func subscriptionAccessActionHandleAction(event: SubscriptionAccessActionHandlingEvent)
}
