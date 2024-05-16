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
import Subscription

public final class ShareSubscriptionAccessModel: SubscriptionAccessModel {

    public var title = UserText.shareModalTitle
    public let description: String
    private var actionHandlers: SubscriptionAccessActionHandlers
    public var email: String?
    public var emailLabel: String { UserText.email }
    public var emailDescription: String { hasEmail ? UserText.shareModalHasEmailDescription : UserText.shareModalNoEmailDescription }
    public var emailButtonTitle: String { hasEmail ? UserText.manageEmailButton : UserText.addEmailButton }
    private let subscriptionManager: SubscriptionManaging

    public init(actionHandlers: SubscriptionAccessActionHandlers, email: String?, subscriptionManager: SubscriptionManaging) {
        self.actionHandlers = actionHandlers
        self.email = email
        self.subscriptionManager = subscriptionManager
        self.description = UserText.shareModalDescription(platform: subscriptionManager.currentEnvironment.purchasePlatform)
    }

    private var hasEmail: Bool { !(email?.isEmpty ?? true) }

    public func handleEmailAction() {
        let type = hasEmail ? SubscriptionURL.manageEmail : SubscriptionURL.addEmail
        let url: URL = subscriptionManager.url(for: type) 

        if hasEmail {
            actionHandlers.uiActionHandler(.postSubscriptionAddEmailClick)
        } else {
            actionHandlers.uiActionHandler(.addDeviceEnterEmail)
        }

        Task {
            if subscriptionManager.currentEnvironment.purchasePlatform == .appStore {
                if #available(macOS 12.0, iOS 15.0, *) {
                    let appStoreAccountManagementFlow = AppStoreAccountManagementFlow(subscriptionManager: subscriptionManager)
                    await appStoreAccountManagementFlow.refreshAuthTokenIfNeeded()
                }
            }

            DispatchQueue.main.async {
                self.actionHandlers.openURLHandler(url)
            }
        }
    }
}
