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
    
    func unlock() {
        let metadata = MacWaitlistMetadata(initialUpgradeCheckComplete: true, unlockCodeVerified: true)
        
        guard let metadataJSONData = metadata.toJSON() else {
            #warning("This is a serious error that will prevent users from unlocking, it should be handled somehow.")
            return
        }

        fileStore.persist(metadataJSONData, url: encryptedMetadataFilePath)
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
