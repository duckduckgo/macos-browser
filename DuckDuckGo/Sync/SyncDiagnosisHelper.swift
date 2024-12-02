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

struct SyncDiagnosisHelper {
    private enum Const {
        static let authStatePixelParamKey = "authState"
    }

    private let userDefaults = UserDefaults.standard
    private let syncService: DDGSyncing

    @UserDefaultsWrapper(key: .syncManuallyDisabledKey)
    private var syncManuallyDisabled: Bool?

    @UserDefaultsWrapper(key: .syncWasDisabledUnexpectedlyPixelFiredKey, defaultValue: false)
    private var syncWasDisabledUnexpectedlyPixelFired: Bool

    init(syncService: DDGSyncing) {
        self.syncService = syncService
    }

// Non-user-initiated deactivation
// For events to help understand the impact of https://app.asana.com/0/1201493110486074/1208538487332133/f

    func didManuallyDisableSync() {
        syncManuallyDisabled = true
    }

    func diagnoseAccountStatus() {
        if syncService.account == nil {
            // Nil value means sync was never on in the first place. So don't fire in this case.
            if syncManuallyDisabled == false,
               !syncWasDisabledUnexpectedlyPixelFired {
                PixelKit.fire(
                    DebugEvent(GeneralPixel.syncDebugWasDisabledUnexpectedly),
                    frequency: .dailyAndCount,
                    withAdditionalParameters: [Const.authStatePixelParamKey: syncService.authState.rawValue]
                )
                syncWasDisabledUnexpectedlyPixelFired = true
            }
        } else {
            syncManuallyDisabled = false
            syncWasDisabledUnexpectedlyPixelFired = false
        }
    }

}

extension UserDefaultsWrapper.DefaultsKey {
    static let syncManuallyDisabledKey = Self(rawValue: "com.duckduckgo.app.key.debug.SyncManuallyDisabled")
    static let syncWasDisabledUnexpectedlyPixelFiredKey = Self(rawValue: "com.duckduckgo.app.key.debug.SyncWasDisabledUnexpectedlyPixelFired")
}
