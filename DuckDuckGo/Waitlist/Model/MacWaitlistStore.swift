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
    private let fileStore: FileStore
    
    init(containerURL: URL = .sandboxApplicationSupportURL,
         fileStore: FileStore = EncryptedFileStore.withDefaultEncryptionKey(),
         statisticsStore: StatisticsStore = LocalStatisticsStore()) {
        self.containerURL = containerURL
        self.statisticsStore = statisticsStore
        self.fileStore = fileStore
    }
    
    func isExistingInstall() -> Bool {
        return statisticsStore.hasInstallStatistics
    }
    
    func isUnlocked() -> Bool {
        guard let metadata = loadMetadataFromDisk() else {
            return false
        }
        
        return metadata.unlockCodeVerified
    }
    
    /// Marks an existing installation of the browser as unlocked, if it has been detected to have been previously installed.
    /// This check is done by inspecting the install date value of the ATB database, leading to two cases:
    ///
    /// 1. **The install date is present**: In this case, the browser will be unlocked
    /// 2. **The install date is not present**: In this case, the browser saves metadata indicating that this check has been already performed, thus future checks
    ///   of the ATB value will be ignored even if it is present.
    func unlockExistingInstallIfNecessary() {
        guard loadMetadataFromDisk() == nil else {
            return
        }
        
        // No metadata was found, meaning that this is the first time that the browser has been run with the lock
        // screen feature included. Check for ATB and unlock the browser if it's present.
        if isExistingInstall() {
            unlock()
        } else {
            saveFailedUnlockAttempt()
        }
    }
    
    func unlock() {
        saveUnlockAttempt(verified: true)
    }
    
    func saveFailedUnlockAttempt() {
        saveUnlockAttempt(verified: false)
    }
    
    private func saveUnlockAttempt(verified: Bool) {
        let metadata = MacWaitlistMetadata(initialUpgradeCheckComplete: true, unlockCodeVerified: verified)
        
        guard let metadataJSONData = metadata.toJSON() else {
            #warning("This is a serious error that will prevent users from unlocking, it should be handled somehow.")
            return
        }

        _ = fileStore.persist(metadataJSONData, url: encryptedMetadataFilePath)
    }
    
    func deleteExistingMetadata() {
        fileStore.remove(fileAtURL: encryptedMetadataFilePath)
    }
    
    private func loadMetadataFromDisk() -> MacWaitlistMetadata? {
        guard let data = fileStore.loadData(at: encryptedMetadataFilePath) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(MacWaitlistMetadata.self, from: data)
    }
    
}
