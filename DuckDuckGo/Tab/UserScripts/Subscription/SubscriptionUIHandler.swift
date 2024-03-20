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
import AppKit
import SubscriptionUI
import Subscription

struct SubscriptionUIHandler {

    var window: NSWindow
    let subscriptionManager: SubscriptionManaging
    var mainViewController: MainViewController

    func showSomethingWentWrongAlert() {
        window.show(.somethingWentWrongAlert())
    }

    func showSubscriptionNotFoundAlert() {
        DispatchQueue.main.async {
            window.show(.subscriptionNotFoundAlert(), firstButtonAction: {
                let purchaseURL = NSApp.delegateTyped.subscriptionManager.urlProvider.url(for: .purchase)
                WindowControllersManager.shared.showTab(with: .subscription(purchaseURL))
            })
        }
    }

    func showSubscriptionInactiveAlert() {
        DispatchQueue.main.async {
            window.show(.subscriptionInactiveAlert(), firstButtonAction: {
                let purchaseURL = NSApp.delegateTyped.subscriptionManager.urlProvider.url(for: .purchase)
                WindowControllersManager.shared.showTab(with: .subscription(purchaseURL))
            })
        }
    }

    func showSubscriptionFoundAlert(originalMessage: WKScriptMessage) {
        DispatchQueue.main.async {
            window.show(.subscriptionFoundAlert(), firstButtonAction: {
                if #available(macOS 12.0, *) {
                    Task {
                        let appStoreRestoreFlow = NSApp.delegateTyped.subscriptionManager.flowProvider.appStoreRestoreFlow
                        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
                        switch result {
                        case .success:
                            DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)
                        case .failure: break
                        }
                        originalMessage.webView?.reload()
                    }
                }
            })
        }
    }

    enum ProgressViewControllerConfiguration {
        case purchasing
        case completing
        case restoring
    }

    func presentProgressViewController(configuration: ProgressViewControllerConfiguration) -> ProgressViewController {

        let title: String?
        switch configuration {
        case .purchasing:
            title = UserText.purchasingSubscriptionTitle
        case .completing:
            title = UserText.completingPurchaseTitle
        case .restoring:
            title = UserText.restoringSubscriptionTitle
        }

        let progressViewController = ProgressViewController(title: title!)
        DispatchQueue.main.async {
            mainViewController.presentAsSheet(progressViewController)
        }
        return progressViewController
    }

    func dismiss(viewController: NSViewController) {
        DispatchQueue.main.async {
            mainViewController.dismiss(viewController)
        }
    }

    func update(progressViewController: ProgressViewController, title: String) {
        DispatchQueue.main.async {
            progressViewController.updateTitleText(UserText.completingPurchaseTitle)
        }
    }

    func showSubscriptionTab(withURL url: URL) {
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .subscription(url))
        }
    }

    func presentSubscriptionAccessViewController(accountManager: AccountManaging,
                                                 actionHandlers: SubscriptionAccessActionHandlers) {
        let vc = SubscriptionAccessViewController(subscriptionManager: subscriptionManager,
                                                  accountManager: accountManager,
                                                  actionHandlers: actionHandlers)
        DispatchQueue.main.async {
            mainViewController.presentAsSheet(vc)
        }
    }

    func showDataBrokerProtectionTab() {
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
        }
    }

    func showIdentityTheftRestorationTab() {
        DispatchQueue.main.async {
            let itrURL = subscriptionManager.urlProvider.url(for: .identityTheftRestoration)
            WindowControllersManager.shared.showTab(with: .identityTheftRestoration(itrURL))
        }
    }
}
