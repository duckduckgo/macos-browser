//
//  SubscriptionUIHandlerMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

public struct SubscriptionUIHandlerMock: SubscriptionUIHandling {

    public enum UIHandlerMockPerformedAction {
        case didPresentProgressViewController
        case didDismissProgressViewController
        case didUpdateProgressViewController
        case didPresentSubscriptionAccessViewController
        case didShowAlert(DuckDuckGo_Privacy_Browser.SubscriptionAlertType)
        case didShowTab(DuckDuckGo_Privacy_Browser.Tab.TabContent)
    }

    let didPerformActionCallback: (_ action: UIHandlerMockPerformedAction) -> Void

    public func presentProgressViewController(withTitle: String) {
        didPerformActionCallback(.didDismissProgressViewController)
    }

    public func dismissProgressViewController() {
        didPerformActionCallback(.didDismissProgressViewController)
    }

    public func updateProgressViewController(title: String) {
        didPerformActionCallback(.didUpdateProgressViewController)
    }

    public func presentSubscriptionAccessViewController(handler: DuckDuckGo_Privacy_Browser.SubscriptionAccessActionHandling, message: WKScriptMessage) {
        didPerformActionCallback(.didPresentSubscriptionAccessViewController)
    }

    public func show(alertType: DuckDuckGo_Privacy_Browser.SubscriptionAlertType) {
        didPerformActionCallback(.didShowAlert(alertType))
    }

    public func show(alertType: DuckDuckGo_Privacy_Browser.SubscriptionAlertType, firstButtonAction: (() -> Void)?) {
        didPerformActionCallback(.didShowAlert(alertType))
    }

    public func show(alertType: DuckDuckGo_Privacy_Browser.SubscriptionAlertType, text: String?) {
        didPerformActionCallback(.didShowAlert(alertType))
    }

    public func showTab(with content: DuckDuckGo_Privacy_Browser.Tab.TabContent) {
        didPerformActionCallback(.didShowTab(content))
    }
}
