//
//  SyncDiagnosisHelper.swift
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
import DDGSync
import PixelKit

final class SyncDiagnosisHelper {
    private struct Consts {
        static let syncManuallyDisabledKey = "com.duckduckgo.app.key.debug.SyncManuallyDisabled"
        static let syncWasDisabledUnexpectedlyPixelFired = "com.duckduckgo.app.key.debug.SyncWasDisabledUnexpectedlyPixelFired"
    }

    private let userDefaults = UserDefaults.standard
    private let syncService: DDGSyncing

    init(syncService: DDGSyncing) {
        self.syncService = syncService
    }

// Non-user-initiated deactivation
// For events to help understand the impact of https://app.asana.com/0/1201493110486074/1208538487332133/f

    func didManuallyDisableSync() {
        userDefaults.set(true, forKey: Consts.syncManuallyDisabledKey)
    }

    func diagnoseAccountStatus() {
        if syncService.account == nil {
            // Nil value means sync was never on in the first place. So don't fire in this case.
            let syncWasManuallyDisabled = userDefaults.value(forKey: Consts.syncManuallyDisabledKey) as? Bool
            if syncWasManuallyDisabled == false,
               !userDefaults.bool(forKey: Consts.syncWasDisabledUnexpectedlyPixelFired) {
                PixelKit.fire(DebugEvent(GeneralPixel.syncDebugWasDisabledUnexpectedly), frequency: .dailyAndCount)
                userDefaults.set(true, forKey: Consts.syncWasDisabledUnexpectedlyPixelFired)
            }
        } else {
            userDefaults.set(false, forKey: Consts.syncManuallyDisabledKey)
            userDefaults.set(false, forKey: Consts.syncWasDisabledUnexpectedlyPixelFired)
        }
    }

}
