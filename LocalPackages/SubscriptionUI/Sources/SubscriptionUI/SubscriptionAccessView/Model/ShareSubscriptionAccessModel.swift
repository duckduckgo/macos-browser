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
    public var description = UserText.shareModalDescription

    private var refreshAuthTokenOnOpenURL: Bool

    private var actionHandlers: SubscriptionAccessActionHandlers

    public var email: String?
    public var emailLabel: String { UserText.email }
    public var emailDescription: String { hasEmail ? UserText.shareModalHasEmailDescription : UserText.shareModalNoEmailDescription }
    public var emailButtonTitle: String { hasEmail ? UserText.manageEmailButton : UserText.addEmailButton }

    private var addEmailURL: URL
    private var manageEmailURL: URL
    private var flowProvider: SubscriptionFlowProviding

    public init(actionHandlers: SubscriptionAccessActionHandlers, email: String?, refreshAuthTokenOnOpenURL: Bool, addEmailURL: URL, manageEmailURL: URL, flowProvider: SubscriptionFlowProviding) {
        self.actionHandlers = actionHandlers
        self.email = email
        self.refreshAuthTokenOnOpenURL = refreshAuthTokenOnOpenURL
        self.addEmailURL = addEmailURL
        self.manageEmailURL = manageEmailURL
        self.flowProvider = flowProvider
    }

    private var hasEmail: Bool { !(email?.isEmpty ?? true) }

    public func handleEmailAction() {
        let url: URL = hasEmail ? manageEmailURL : addEmailURL

        if hasEmail {
            actionHandlers.uiActionHandler(.postSubscriptionAddEmailClick)
        } else {
            actionHandlers.uiActionHandler(.addDeviceEnterEmail)
        }

        Task {
            if refreshAuthTokenOnOpenURL {
                if #available(macOS 12.0, iOS 15.0, *) {
                    await flowProvider.appStoreAccountManagementFlow.refreshAuthTokenIfNeeded()
                }
            }

            DispatchQueue.main.async {
                self.actionHandlers.openURLHandler(url)
            }
        }
    }
}
