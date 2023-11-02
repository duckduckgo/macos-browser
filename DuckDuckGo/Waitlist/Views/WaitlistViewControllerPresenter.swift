//
//  WaitlistViewControllerPresenter.swift
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
import UserNotifications

#if NETWORK_PROTECTION || DBP

protocol WaitlistViewControllerPresenter {
    static func show(completion: (() -> Void)?)
}

extension WaitlistViewControllerPresenter {
    static func show(completion: (() -> Void)? = nil) {
        Self.show(completion: nil)
    }
}

#endif

#if NETWORK_PROTECTION

struct NetworkProtectionWaitlistViewControllerPresenter: WaitlistViewControllerPresenter {

    @MainActor
    static func show(completion: (() -> Void)? = nil) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            return
        }

        // This is a hack to get around an issue with the waitlist notification screen showing the wrong state while it animates in, and then
        // jumping to the correct state as soon as the animation is complete. This works around that problem by providing the correct state up front,
        // preventing any state changing from occurring.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let state = WaitlistViewModel.NotificationPermissionState.from(status)

            DispatchQueue.main.async {
                let viewModel = WaitlistViewModel(waitlist: NetworkProtectionWaitlist(),
                                                  notificationPermissionState: state,
                                                  termsAndConditionActionHandler: NetworkProtectionWaitlistTermsAndConditionsActionHandler(),
                                                  featureSetupHandler: NetworkProtectionWaitlistFeatureSetupHandler())

                let viewController = WaitlistModalViewController(viewModel: viewModel, contentView: NetworkProtectionWaitlistRootView())
                windowController.mainViewController.beginSheet(viewController) { _ in
                    completion?()
                }
            }
        }
    }
}

#endif

#if DBP

struct DataBrokerProtectionWaitlistViewControllerPresenter: WaitlistViewControllerPresenter {

    static func shouldPresentWaitlist() -> Bool {
        let waitlist = DataBrokerProtectionWaitlist()

        let accepted = UserDefaults().bool(forKey: UserDefaultsWrapper<Bool>.Key.dataBrokerProtectionTermsAndConditionsAccepted.rawValue)

        return !(waitlist.waitlistStorage.isInvited && accepted)
    }

    @MainActor
    static func show(completion: (() -> Void)? = nil) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            return
        }
        // This is a hack to get around an issue with the waitlist notification screen showing the wrong state while it animates in, and then
        // jumping to the correct state as soon as the animation is complete. This works around that problem by providing the correct state up front,
        // preventing any state changing from occurring.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let state = WaitlistViewModel.NotificationPermissionState.from(status)
            DispatchQueue.main.async {
                let viewModel = WaitlistViewModel(waitlist: DataBrokerProtectionWaitlist(),
                                                  notificationPermissionState: state,
                                                  termsAndConditionActionHandler: DataBrokerProtectionWaitlistTermsAndConditionsActionHandler(),
                                                  featureSetupHandler: DataBrokerProtectionWaitlistFeatureSetupHandler())

                let viewController = WaitlistModalViewController(viewModel: viewModel, contentView: DataBrokerProtectionWaitlistRootView())
                windowController.mainViewController.beginSheet(viewController) { _ in
                    completion?()
                }
            }
        }
    }
}

#endif
