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

        guard featureVisibility.isFeatureVisible() else {
            featureVisibility.disableAndDeleteForWaitlistUsers()
            return
        }

        Task {
            try? await DataBrokerProtectionWaitlist().redeemDataBrokerProtectionInviteCodeIfAvailable()
        }

        restartBackgroundAgent(loginItemsManager: loginItemsManager)
    }

    func applicationDidBecomeActive() {
        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility()

        guard featureVisibility.isFeatureVisible() else {
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
                DailyPixel.fire(pixel: .dataBrokerProtectionWaitlistCardUITapped,
                                frequency: .dailyAndCount,
                                includeAppVersionParameter: true)
            case .localPush:
                DailyPixel.fire(pixel: .dataBrokerProtectionWaitlistNotificationTapped,
                                frequency: .dailyAndCount,
                                includeAppVersionParameter: true)
            }

            DataBrokerProtectionWaitlistViewControllerPresenter.show()
        }
    }

    func windowDidBecomeMain() {
        sendActiveDataBrokerProtectionWaitlistUserPixel()
    }

    private func sendActiveDataBrokerProtectionWaitlistUserPixel() {
        if DefaultDataBrokerProtectionFeatureVisibility().waitlistIsOngoing {
            DailyPixel.fire(pixel: .dataBrokerProtectionWaitlistUserActive,
                            frequency: .dailyOnly,
                            includeAppVersionParameter: true)
        }
    }

    private func restartBackgroundAgent(loginItemsManager: LoginItemsManager) {
        pixelHandler.fire(.resetLoginItem)
        loginItemsManager.restartLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)
    }
}
