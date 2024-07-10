//
//  StatisticsStore.swift
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit

protocol StatisticsStore: BrowserServicesKit.StatisticsStore {

    var lastAppRetentionRequestDate: Date? { get set }
    var isAppRetentionFiredToday: Bool { get }

    var waitlistUnlocked: Bool { get set }

    var autoLockEnabled: Bool { get set }
    var autoLockThreshold: String? { get set }

}

extension StatisticsStore {

    var atbWithVariant: String? {
        guard let atb = atb else { return nil }
        return atb + (variant ?? "")
    }

    var hasInstallStatistics: Bool {
        return atb != nil
    }

    var isAppRetentionFiredToday: Bool {
        Date.startOfDayToday == lastAppRetentionRequestDate.map(Calendar.current.startOfDay)
    }

}
