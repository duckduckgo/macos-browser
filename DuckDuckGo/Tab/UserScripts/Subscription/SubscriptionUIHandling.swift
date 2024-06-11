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
    // MARK: - ProgressViewController
    func presentProgressViewController(withTitle: String)
    // let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
    // let progressViewController = await ProgressViewController(title: UserText.purchasingSubscriptionTitle)

    func dismissProgressViewController()
    // await mainViewController?.dismiss(progressViewController)

    func updateProgressViewController(title: String)
    // await progressViewController.updateTitleText(UserText.completingPurchaseTitle)

    // MARK: - SubscriptionAccessViewController
    func presentSubscriptionAccessViewController(handler: SubscriptionAccessActionHandling, message: WKScriptMessage)
/*
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

 */

    // MARK: Alerts
    func show(alertType: SubscriptionAlertType)
    func show(alertType: SubscriptionAlertType, firstButtonAction: (() -> Void)?)
    func show(alertType: SubscriptionAlertType, text: String?)
/*
    func show(_ alert: NSAlert, firstButtonAction: (() -> Void)? = nil) {
        alert.beginSheetModal(for: self, completionHandler: { response in
            if case .alertFirstButtonReturn = response {
                firstButtonAction?()
            }
        })
    }

 //        guard let window else { return }
 //        window.show(.subscriptionFoundAlert(), firstButtonAction: {
 */

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
