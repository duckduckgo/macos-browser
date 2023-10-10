//
//  DataBrokerProtectionUpdater.swift
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
import Common

protocol ResourcesRepository {
    func fetchBrokerFromResourceFiles() -> [DataBroker]?
}

final class FileResources: ResourcesRepository {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fetchBrokerFromResourceFiles() -> [DataBroker]? {
        guard let resourceURL = Bundle.module.resourceURL else {
            return nil
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let brokerJSONFiles = fileURLs.filter {
                $0.isJSON && !$0.hasFakePrefix
            }

            return brokerJSONFiles.map(DataBroker.initFromResource(_:))
        } catch {
            os_log("Error fetching brokers JSON files from resources", log: .dataBrokerProtection)
            return nil
        }
    }
}

protocol BrokerUpdaterRepository {

    func saveLastRunDate(date: Date)
    func getLastRunDate() -> Date?
}

final class BrokerUpdaterUserDefaults: BrokerUpdaterRepository {

    struct Consts {
        static let shouldCheckForUpdatesKey = "macos.browser.data-broker-protection.ShouldCheckForNewBrokers"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveLastRunDate(date: Date) {
        UserDefaults.standard.set(date, forKey: Consts.shouldCheckForUpdatesKey)
    }

    func getLastRunDate() -> Date? {
        guard let lastRunDateData = UserDefaults.standard.object(forKey: Consts.shouldCheckForUpdatesKey) as? Date else { return nil }

        return lastRunDateData
    }
}

struct DataBrokerProtectionBrokerUpdater {

    struct Consts {
        static let updateWindow: Double = 24
    }

    private let repository: BrokerUpdaterRepository
    private let resources: ResourcesRepository
    private let vault: any DataBrokerProtectionSecureVault

    init(repository: BrokerUpdaterRepository = BrokerUpdaterUserDefaults(),
         resources: ResourcesRepository = FileResources(),
         vault: any DataBrokerProtectionSecureVault) {
        self.repository = repository
        self.resources = resources
        self.vault = vault
    }

    func checkForUpdatesInBrokerJSONFiles() {
        if let lastRunDate = repository.getLastRunDate() {
            if hasHoursPassed(hours: Consts.updateWindow, from: lastRunDate, to: Date()) {
                updateBrokers()
            }
        } else {
            // Last run date is nil. Probably it was not set yet, so we need to check for updates.
            updateBrokers()
        }
    }

    private func updateBrokers() {
        repository.saveLastRunDate(date: Date())
        guard let brokers = resources.fetchBrokerFromResourceFiles() else { return }

        for broker in brokers {
            do {
                try update(broker)
            } catch {
                os_log("Error updating broker: %{public}@, with version: %{public}@", log: .dataBrokerProtection, broker.name, broker.version)
            }
        }
    }

    // Here we check if we need to update broker files
    //
    // 1. We check if the broker exists in the database
    // 2. If does exist, we check the number version, if the version number is new, we update it
    // 3. If it does not exist, we add it, and we create the scan operations related to it
    private func update(_ broker: DataBroker) throws {
        guard let savedBroker = try vault.fetchBroker(with: broker.name) else {
            // The broker does not exist in the current storage. We need to add it.
            try add(broker)
            return
        }

        if shouldUpdate(incomingBrokerVersion: broker.version, storedVersion: savedBroker.version) {
            guard let savedBrokerId = savedBroker.id else { return }

            try vault.update(broker, with: savedBrokerId)
        }
    }

    // 1. We save the broker into the database
    // 2. We fetch the user profile and obtain the profile queries
    // 3. We create the new scans operations for the profile queries and the new broker id
    private func add(_ broker: DataBroker) throws {
        let brokerId = try vault.save(broker: broker)
        let profileQueries = try vault.fetchAllProfileQueries(for: 1)
        let profileQueryIDs = profileQueries.compactMap({ $0.id })

        for profileQueryId in profileQueryIDs {
            try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: Date())
        }
    }

    private func shouldUpdate(incomingBrokerVersion: String, storedVersion: String) -> Bool {
        let result = incomingBrokerVersion.compare(storedVersion, options: .numeric)

        return result == .orderedDescending
    }

    private func hasHoursPassed(hours: Double, from startDate: Date, to endDate: Date) -> Bool {
        let timeInterval = endDate.timeIntervalSince(startDate)
        let hoursPassed = timeInterval / 3600  // 3600 seconds in an hour

        return hoursPassed >= hours
    }
}

fileprivate extension URL {

    var isJSON: Bool {
        self.pathExtension.lowercased() == "json"
    }

    var hasFakePrefix: Bool {
        self.lastPathComponent.lowercased().hasPrefix("fake")
    }
}
