//
//  DataBrokerProtectionAppEvents.swift
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

#if DBP

import Foundation
import LoginItems
import Common
import DataBrokerProtection

struct DataBrokerProtectionAppEvents {
    let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()

    enum WaitlistNotificationSource {
        case localPush
        case cardUI
    }

    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()
        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility()

        guard !featureVisibility.cleanUpDBPForPrivacyProIfNecessary() else { return }

        /// If the user is not in the waitlist and Privacy Pro flag is false, we want to remove the data for waitlist users
        /// since the waitlist flag might have been turned off
        if !featureVisibility.isFeatureVisible() && !featureVisibility.isPrivacyProEnabled() {
            featureVisibility.disableAndDeleteForWaitlistUsers()
            return
        }

        Task {
            try? await DataBrokerProtectionWaitlist().redeemDataBrokerProtectionInviteCodeIfAvailable()

            // If we don't have profileQueries it means there's no user profile saved in our DB
            // In this case, let's disable the agent and delete any left-over data because there's nothing for it to do
            if let profileQueries = try? DataBrokerProtectionManager.shared.dataManager.fetchBrokerProfileQueryData(ignoresCache: true),
               profileQueries.count > 0 {
                restartBackgroundAgent(loginItemsManager: loginItemsManager)
            } else {
                featureVisibility.disableAndDeleteForWaitlistUsers()
            }
        }

    }

    func applicationDidBecomeActive() {
        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility()

        guard !featureVisibility.cleanUpDBPForPrivacyProIfNecessary() else { return }

        /// If the user is not in the waitlist and Privacy Pro flag is false, we want to remove the data for waitlist users
        /// since the waitlist flag might have been turned off
        if !featureVisibility.isFeatureVisible() && !featureVisibility.isPrivacyProEnabled() {
            featureVisibility.disableAndDeleteForWaitlistUsers()
            return
        }

        Task {
            try? await DataBrokerProtectionWaitlist().redeemDataBrokerProtectionInviteCodeIfAvailable()
        }
    }

    @MainActor
    func handleWaitlistInvitedNotification(source: WaitlistNotificationSource) {
        if DataBrokerProtectionWaitlist().readyToAcceptTermsAndConditions {
            switch source {
            case .cardUI:
                DataBrokerProtectionExternalWaitlistPixels.fire(pixel: GeneralPixel.dataBrokerProtectionWaitlistCardUITapped, frequency: .dailyAndCount)
            case .localPush:
                DataBrokerProtectionExternalWaitlistPixels.fire(pixel: GeneralPixel.dataBrokerProtectionWaitlistNotificationTapped, frequency: .dailyAndCount)
            }

            DataBrokerProtectionWaitlistViewControllerPresenter.show()
        }
    }

    func windowDidBecomeMain() {
        sendActiveDataBrokerProtectionWaitlistUserPixel()
    }

    private func sendActiveDataBrokerProtectionWaitlistUserPixel() {
        if DefaultDataBrokerProtectionFeatureVisibility().waitlistIsOngoing {
            DataBrokerProtectionExternalWaitlistPixels.fire(pixel: GeneralPixel.dataBrokerProtectionWaitlistUserActive, frequency: .daily)
        }
    }

    private func restartBackgroundAgent(loginItemsManager: LoginItemsManager) {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerResetLoginItemDaily, frequency: .daily)
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)

        // restartLoginItems doesn't work when we change the agent name
    }
}

#endif
