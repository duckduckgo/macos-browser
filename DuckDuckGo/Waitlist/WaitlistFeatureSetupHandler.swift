//
//  WaitlistFeatureSetupHandler.swift
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

protocol WaitlistFeatureSetupHandler {
    func confirmFeature()
}

#endif

#if NETWORK_PROTECTION

struct NetworkProtectionWaitlistFeatureSetupHandler: WaitlistFeatureSetupHandler {
    func confirmFeature() {
        LocalPinningManager.shared.pin(.networkProtection)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
    }
}

#endif

#if DBP

struct DataBrokerProtectionWaitlistFeatureSetupHandler: WaitlistFeatureSetupHandler {
    func confirmFeature() {
        NotificationCenter.default.post(name: .dataBrokerProtectionWaitlistAccessChanged, object: nil)
        NotificationCenter.default.post(name: .dataBrokerProtectionUserPressedOnGetStartedOnWaitlist, object: nil)
        UserDefaults().setValue(false, forKey: UserDefaultsWrapper<Bool>.Key.shouldShowDBPWaitlistInvitedCardUI.rawValue)
    }
}

#endif
