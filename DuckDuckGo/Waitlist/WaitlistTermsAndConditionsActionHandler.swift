//
//  WaitlistTermsAndConditionsActionHandler.swift
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

#if NETWORK_PROTECTION || DBP

import Foundation
import UserNotifications

protocol WaitlistTermsAndConditionsActionHandler {
    var acceptedTermsAndConditions: Bool { get }
    func didShow()
    mutating func didAccept()
}

#endif

#if NETWORK_PROTECTION

struct NetworkProtectionWaitlistTermsAndConditionsActionHandler: WaitlistTermsAndConditionsActionHandler {
    @UserDefaultsWrapper(key: .networkProtectionTermsAndConditionsAccepted, defaultValue: false)
    var acceptedTermsAndConditions: Bool

    func didShow() {
        // Intentional no-op
    }

    mutating func didAccept() {
        acceptedTermsAndConditions = true
        // Remove delivered NetP notifications in case the user didn't click them.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [NetworkProtectionWaitlist.notificationIdentifier])
    }
}

#endif

#if DBP

struct DataBrokerProtectionWaitlistTermsAndConditionsActionHandler: WaitlistTermsAndConditionsActionHandler {
    @UserDefaultsWrapper(key: .dataBrokerProtectionTermsAndConditionsAccepted, defaultValue: false)
    var acceptedTermsAndConditions: Bool

    func didShow() {
        DataBrokerProtectionExternalWaitlistPixels.fire(pixel: .dataBrokerProtectionWaitlistTermsAndConditionsDisplayed, frequency: .dailyAndCount)
    }

    mutating func didAccept() {
        acceptedTermsAndConditions = true
        // Remove delivered NetP notifications in case the user didn't click them.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [DataBrokerProtectionWaitlist.notificationIdentifier])

        DataBrokerProtectionExternalWaitlistPixels.fire(pixel: .dataBrokerProtectionWaitlistTermsAndConditionsAccepted, frequency: .dailyAndCount)
    }
}

#endif
