//
//  SubscriptionUIHandler.swift
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

import AppKit
import SubscriptionUI
import WebKit

@MainActor
final class SubscriptionUIHandler: SubscriptionUIHandling {

    fileprivate var windowControllersManager: WindowControllersManager { windowControllersManagerProvider() }
    fileprivate var mainWindowController: MainWindowController? { windowControllersManager.lastKeyMainWindowController }
    fileprivate var currentWindow: NSWindow? { mainWindowController?.window }
    fileprivate var currentMainViewController: MainViewController? { mainWindowController?.mainViewController }

    typealias WindowControllersManagerProvider = () -> WindowControllersManager
    fileprivate nonisolated let windowControllersManagerProvider: WindowControllersManagerProvider
    fileprivate var progressViewController: ProgressViewController?

    @MainActor init(windowControllersManagerProvider: @escaping WindowControllersManagerProvider) {
        self.windowControllersManagerProvider = windowControllersManagerProvider
    }

    // MARK: - SubscriptionUIHandling

    func presentProgressViewController(withTitle title: String) {
        let newProgressViewController = ProgressViewController(title: title)
        currentMainViewController?.presentAsSheet(newProgressViewController)
        progressViewController = newProgressViewController
    }

    func dismissProgressViewController() {
        progressViewController?.dismiss()
        progressViewController = nil
    }

    func updateProgressViewController(title: String) {
        progressViewController?.updateTitleText(title)
    }

    func presentSubscriptionAccessViewController(handler: any SubscriptionAccessActionHandling, message: WKScriptMessage) {
        let actionHandlers = SubscriptionAccessActionHandlers(openActivateViaEmailURL: {
            let url = Application.appDelegate.subscriptionManager.url(for: .activateViaEmail)
            handler.subscriptionAccessActionOpenURLHandler(url: url)
        }, restorePurchases: {
            handler.subscriptionAccessActionRestorePurchases(message: message)
        }, uiActionHandler: { event in
            handler.subscriptionAccessActionHandleAction(event: event)
        })

        let newSubscriptionAccessViewController = SubscriptionAccessViewController(subscriptionManager: Application.appDelegate.subscriptionManager,
                                                                                   actionHandlers: actionHandlers)
        currentMainViewController?.presentAsSheet(newSubscriptionAccessViewController)
    }

    @discardableResult
    func dismissProgressViewAndShow(alertType: SubscriptionAlertType, text: String?) async -> NSApplication.ModalResponse {
        dismissProgressViewController()
        return await show(alertType: alertType, text: text)
    }

    @discardableResult
    func show(alertType: SubscriptionAlertType, text: String?) async -> NSApplication.ModalResponse {
        var alert: NSAlert {
            switch alertType {
            case .somethingWentWrong:
                return .somethingWentWrongAlert()
            case .subscriptionNotFound:
                return .subscriptionNotFoundAlert()
            case .subscriptionInactive:
                return .subscriptionInactiveAlert()
            case .subscriptionFound:
                return .subscriptionFoundAlert()
            case .appleIDSyncFailed:
                return .appleIDSyncFailedAlert(text: text ?? "Error")
            }
        }

        guard let currentWindow else {
            assertionFailure("Missing current window")
            return .alertSecondButtonReturn
        }

        return await alert.beginSheetModal(for: currentWindow)
    }

    func showTab(with content: Tab.TabContent) {
        self.windowControllersManager.showTab(with: content)
    }
}
