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

public final class SubscriptionUIHandlerMock: SubscriptionUIHandling {

    public enum UIHandlerMockPerformedAction: Equatable {
        case didPresentProgressViewController
        case didDismissProgressViewController
        case didUpdateProgressViewController
        case didPresentSubscriptionAccessViewController
        case didShowAlert(SubscriptionAlertType)
        case didShowTab(Tab.TabContent)
    }

    var didPerformActionCallback: (_ action: UIHandlerMockPerformedAction) -> Void

    public init(alertResponse: NSApplication.ModalResponse? = nil,
                didPerformActionCallback: @escaping (UIHandlerMockPerformedAction) -> Void) {
        self.didPerformActionCallback = didPerformActionCallback
        self.alertResponse = alertResponse
    }

    @MainActor
    public func setDidPerformActionCallback(callback: @escaping (_ action: UIHandlerMockPerformedAction) -> Void) {
        self.didPerformActionCallback = callback
    }

    @MainActor
    public func setAlertResponse(alertResponse: NSApplication.ModalResponse?) {
        self.alertResponse = alertResponse
    }

    public var alertResponse: NSApplication.ModalResponse?

    public func presentProgressViewController(withTitle: String) {
        didPerformActionCallback(.didPresentProgressViewController)
    }

    public func dismissProgressViewController() {
        didPerformActionCallback(.didDismissProgressViewController)
    }

    public func updateProgressViewController(title: String) {
        didPerformActionCallback(.didUpdateProgressViewController)
    }

    public func presentSubscriptionAccessViewController(handler: SubscriptionAccessActionHandling, message: WKScriptMessage) {
        didPerformActionCallback(.didPresentSubscriptionAccessViewController)
    }

    @discardableResult
    public func dismissProgressViewAndShow(alertType: SubscriptionAlertType, text: String?) async -> NSApplication.ModalResponse {
        dismissProgressViewController()
        return await show(alertType: alertType, text: text)
    }

    @discardableResult
    public func show(alertType: SubscriptionAlertType, text: String?) async -> NSApplication.ModalResponse {
        didPerformActionCallback(.didShowAlert(alertType))
        return alertResponse!
    }

    public func showTab(with content: Tab.TabContent) {
        didPerformActionCallback(.didShowTab(content))
    }
}
