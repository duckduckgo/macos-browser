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

import Foundation
import SubscriptionUI

@MainActor
final class SubscriptionUIHandler: SubscriptionUIHandling {

//    func getCurrentMainViewController() async -> MainViewController  {
//        guard let viewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else {
//            assertionFailure("Missing current main view controller")
//        }
//        return viewController
//    }
//
//    @MainActor
//    var window: NSWindow? {
//        WindowControllersManager.shared.lastKeyMainWindowController?.window
//    }

    var currentWindow: NSWindow? {
        windowControllersManagerProvider().lastKeyMainWindowController?.window
    }

    var currentMainViewController: MainViewController? {
        windowControllersManagerProvider().lastKeyMainWindowController?.mainViewController
    }

    var windowControllersManager: WindowControllersManager {
        windowControllersManagerProvider()
    }

    typealias WindowControllersManagerProvider = () -> WindowControllersManager
    nonisolated let windowControllersManagerProvider: WindowControllersManagerProvider

    nonisolated init(windowControllersManagerProvider: @escaping WindowControllersManagerProvider) {
        self.windowControllersManagerProvider = windowControllersManagerProvider
    }

    var progressViewController: ProgressViewController?
    var subscriptionAccessViewController: SubscriptionAccessViewController?

    // MARK: - SubscriptionUIHandling

    func presentProgressViewController(withTitle: String) {
        progressViewController = ProgressViewController(title: UserText.purchasingSubscriptionTitle)
        currentMainViewController?.presentAsSheet(progressViewController!)
    }

    func dismissProgressViewController() {
        currentMainViewController?.dismiss(progressViewController)
        progressViewController = nil
    }

    func updateProgressViewController(title: String) {
        progressViewController?.updateTitleText(UserText.completingPurchaseTitle)
    }

    /*
     func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {

         PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseOfferPageEntry)
         guard let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController,
               let windowControllerManager = await WindowControllersManager.shared.lastKeyMainWindowController else {
             return nil
         }
         let message = original

         let actionHandlers = SubscriptionAccessActionHandlers(restorePurchases: {
             if #available(macOS 12.0, *) {
                 Task { @MainActor in
                     let subscriptionAppStoreRestorer = SubscriptionAppStoreRestorer(subscriptionManager: self.subscriptionManager)
                     await subscriptionAppStoreRestorer.restoreAppStoreSubscription(mainViewController: mainViewController, windowController: windowControllerManager)
                     message.webView?.reload()
                 }
             }
         }, openURLHandler: { url in
             DispatchQueue.main.async {
                 WindowControllersManager.shared.showTab(with: .subscription(url))
             }
         }, uiActionHandler: { event in
             switch event {
             case .activateAddEmailClick:
                 PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
             default:
                 break
             }
         })

         let subscriptionAccessViewController = await SubscriptionAccessViewController(subscriptionManager: subscriptionManager, actionHandlers: actionHandlers)
         await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.presentAsSheet(subscriptionAccessViewController)

         return nil
     }
     */
    func presentSubscriptionAccessViewController(handler: any SubscriptionAccessActionHandling, message: WKScriptMessage) {

        if let previousVC = subscriptionAccessViewController {
            self.currentMainViewController?.dismiss(previousVC)
        }

        let actionHandlers = SubscriptionAccessActionHandlers(restorePurchases: {
            handler.subscriptionAccessActionRestorePurchases(message: message)
        }, openURLHandler: { url in
            handler.subscriptionAccessActionOpenURLHandler(url: url)
        }, uiActionHandler: { event in
            handler.subscriptionAccessActionHandleAction(event: event)
        })

        subscriptionAccessViewController = SubscriptionAccessViewController(
            subscriptionManager: Application.appDelegate.subscriptionManager,
            actionHandlers: actionHandlers)
        currentMainViewController?.presentAsSheet(self.subscriptionAccessViewController!)
    }

    func show(alertType: SubscriptionAlertType, text: String? = nil, firstButtonAction: (() -> Void)? = nil) {

        var alert: NSAlert?
        switch alertType {
        case .somethingWentWrong:
            alert = .somethingWentWrongAlert()
        case .subscriptionNotFound:
            alert = .subscriptionNotFoundAlert()
        case .subscriptionInactive:
            alert = .subscriptionInactiveAlert()
        case .subscriptionFound:
            alert = .subscriptionFoundAlert()
        case .appleIDSyncFailed:
            guard let text else {
                assertionFailure("Trying to present appleIDSyncFailed alert without required text")
                return
            }
            alert = .appleIDSyncFailedAlert(text: text)
        }

        guard let alert else {
            assertionFailure("Missing subscription alert")
            return
        }

        currentWindow?.show(alert, firstButtonAction: firstButtonAction)
    }

    func show(alertType: SubscriptionAlertType) {
        show(alertType: alertType, text: nil, firstButtonAction: nil)
    }

    func show(alertType: SubscriptionAlertType, firstButtonAction: (() -> Void)?) {
        show(alertType: alertType, text: nil, firstButtonAction: firstButtonAction)
    }

    func show(alertType: SubscriptionAlertType, text: String?) {
        show(alertType: alertType, text: text, firstButtonAction: nil)
    }

    func showTab(with content: Tab.TabContent) {
        self.windowControllersManager.showTab(with: content)
    }
}
