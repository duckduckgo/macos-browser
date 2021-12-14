//
//  MacWaitlistStore.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

protocol MacWaitlistStore {
    
    func isExistingInstall() -> Bool
    func isUnlocked() -> Bool
    func unlock()
    
}

final class MacWaitlistEncryptedFileStorage: MacWaitlistStore {
    
    private var encryptedMetadataFilePath: URL {
        return containerURL.appendingPathComponent("Configuration").appendingPathComponent("LaunchConfiguration")
    }

    private let containerURL: URL
    private let statisticsStore: StatisticsStore
    
    init(containerURL: URL = .sandboxApplicationSupportURL, statisticsStore: StatisticsStore = LocalStatisticsStore()) {
        self.containerURL = containerURL
        self.statisticsStore = statisticsStore
    }
    
    func isExistingInstall() -> Bool {
        return statisticsStore.hasInstallStatistics
    }
    
    func isUnlocked() -> Bool {
        return statisticsStore.waitlistUnlocked
    }
    
    /// Marks an existing installation of the browser as unlocked, if it has been detected to have been previously installed.
    /// This check is done by inspecting the install date value of the ATB database, leading to two cases:
    ///
    /// 1. **The install date is present**: In this case, the browser will be unlocked
    /// 2. **The install date is not present**: In this case, the browser saves metadata indicating that this check has been already performed, thus future checks
    ///   of the ATB value will be ignored even if it is present.
    func unlockExistingInstallIfNecessary() {
        guard !statisticsStore.waitlistUpgradeCheckComplete else {
            return
        }
        
        // No waitlist check has been performed, meaning that this is the first time that the browser has been run with
        //  the lock screen feature included. Check for ATB and unlock the browser if it's present.
        if isExistingInstall() {
            unlock()
        } else {
            saveFailedUnlockAttempt()
        }
    }
    
    func unlock() {
        statisticsStore.waitlistUpgradeCheckComplete = true
        statisticsStore.waitlistUnlocked = true
    }
    
    func saveFailedUnlockAttempt() {
        statisticsStore.waitlistUpgradeCheckComplete = true
    }
    
    func deleteExistingMetadata() {
        statisticsStore.waitlistUpgradeCheckComplete = false
        statisticsStore.waitlistUnlocked = false
    }
    
}
