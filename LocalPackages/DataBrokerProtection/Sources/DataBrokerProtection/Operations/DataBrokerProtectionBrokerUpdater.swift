//
//  DataBrokerProtectionBrokerUpdater.swift
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
import MacOSCommon
import Cocoa
import SecureStorage

protocol ResourcesRepository {
    func fetchBrokerFromResourceFiles() throws -> [DataBroker]?
    func removeExistingBrokersAndReplaceWithDebugBrokers() throws
}

final class FileResources: ResourcesRepository {

    enum FileResourcesError: Error {
        case bundleResourceURLNil
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fetchBrokerFromResourceFiles() throws -> [DataBroker]? {
        guard let resourceURL = Bundle.module.resourceURL else {
            assertionFailure()
            os_log("DataBrokerProtectionUpdater: error FileResources fetchBrokerFromResourceFiles, error: Bundle.module.resourceURL is nil", log: .error)
            throw FileResourcesError.bundleResourceURLNil
        }

        let shouldUseFakeBrokers = (NSApp.runType == .integrationTests)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let brokerJSONFiles = fileURLs.filter {
                $0.isJSON && (
                (shouldUseFakeBrokers && $0.hasFakePrefix) ||
                (!shouldUseFakeBrokers && !$0.hasFakePrefix))
            }

            return try brokerJSONFiles.map(DataBroker.initFromResource(_:))
        } catch {
            os_log("DataBrokerProtectionUpdater: error FileResources error: fetchBrokerFromResourceFiles, error: %{public}@", log: .error, error.localizedDescription)
            throw error
        }
    }

    func removeExistingBrokersAndReplaceWithDebugBrokers() throws {
        /*
        hmm if we go with this approach it needs to be strictly for running the tests
        cos otherwise the bundle singiture will change
        the alternative would be to make this point at a different directory
        I prefer that, but kinda wildly it gets _all_ json files in resources, so that would need to change
        I think...yeah? Just change that? Although I'm worried it's used elsewhere
         I'm not sure how we pull this in from FE, I might need to align there
        that settles it, keep it as is for now and do the easier thing

        I suppose another approach is having a more global "Debug mode" and then changing the fetchBrokerFromResourceFiles function itself to take that into account

        for now fuck the signiture. yeet the files except for the debug ones

        hmm now it's not ui tests, deleting them works, but, it'll fuck any other tests?
        I think they run sepertly so is fine
        gonna run with it for now

        is this enough, do we need to yeet the DB somewhere?
         in fact, the app is still gonna use fetchBrokerFromResourceFiles, so what is the point?

        okay, we could rename the debug ones so the other thing doens't pick them up
        or we could jsut do "IF INTEGRATION TEST" above
        I think I might actually prefer the former, even though it's a lot more complicateda
         */

        guard let resourceURL = Bundle.module.resourceURL else {
            assertionFailure()
            os_log("DataBrokerProtectionUpdater: error FileResources fetchBrokerFromResourceFiles, error: Bundle.module.resourceURL is nil", log: .error)
            throw FileResourcesError.bundleResourceURLNil
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            // Delete the non debug brokers
            let brokerJSONFileURLsToDelete = fileURLs.filter {
                $0.isJSON && !$0.isDebugBroker
            }

            for fileURL in brokerJSONFileURLsToDelete {
                try fileManager.removeItem(at: fileURL)
            }

            // Rename the fake brokers so they will no longer be ignored by fetchBrokerFromResourceFiles()
            for fileURL in fileURLs.filter({ $0.isDebugBroker }) {
                let newName = fileURL.lastPathComponent.dropping(prefix: "fake")
                let newURL = fileURL.deletingLastPathComponent().appendingPathComponent(newName)
                try fileManager.moveItem(at: fileURL, to: newURL)
            }
        } catch {
            os_log("DataBrokerProtectionUpdater: error FileResources error: fetchBrokerFromResourceFiles, error: %{public}@", log: .error, error.localizedDescription)
            throw error
        }
    }
}

protocol BrokerUpdaterRepository {

    func saveLatestAppVersionCheck(version: String)
    func getLastCheckedVersion() -> String?
}

final class BrokerUpdaterUserDefaults: BrokerUpdaterRepository {

    struct Consts {
        static let shouldCheckForUpdatesKey = "macos.browser.data-broker-protection.LastLocalVersionChecked"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveLatestAppVersionCheck(version: String) {
        UserDefaults.standard.set(version, forKey: Consts.shouldCheckForUpdatesKey)
    }

    func getLastCheckedVersion() -> String? {
        UserDefaults.standard.string(forKey: Consts.shouldCheckForUpdatesKey)
    }
}

protocol AppVersionNumberProvider {
    var versionNumber: String { get }
}

final class AppVersionNumber: AppVersionNumberProvider {

    var versionNumber: String = AppVersion.shared.versionNumber
}

protocol DataBrokerProtectionBrokerUpdaterProductionInterface {
    func updateBrokers()
    func checkForUpdatesInBrokerJSONFiles()
}

protocol DataBrokerProtectionBrokerUpdaterDebugInterface {
    static func provideForDebug() -> DefaultDataBrokerProtectionBrokerUpdater?
    func replaceAllBrokersWithDebugBrokers() throws
}

protocol DataBrokerProtectionBrokerUpdater: DataBrokerProtectionBrokerUpdaterProductionInterface, DataBrokerProtectionBrokerUpdaterDebugInterface {
}

public struct DefaultDataBrokerProtectionBrokerUpdater: DataBrokerProtectionBrokerUpdater {

    private let repository: BrokerUpdaterRepository
    private let resources: ResourcesRepository
    private let vault: any DataBrokerProtectionSecureVault
    private let appVersion: AppVersionNumberProvider
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    init(repository: BrokerUpdaterRepository = BrokerUpdaterUserDefaults(),
         resources: ResourcesRepository = FileResources(),
         vault: any DataBrokerProtectionSecureVault,
         appVersion: AppVersionNumberProvider = AppVersionNumber(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()) {
        self.repository = repository
        self.resources = resources
        self.vault = vault
        self.appVersion = appVersion
        self.pixelHandler = pixelHandler
    }

    public func updateBrokers() {
        let brokers: [DataBroker]?
        do {
            brokers = try resources.fetchBrokerFromResourceFiles()
        } catch {
            os_log("DataBrokerProtectionBrokerUpdater updateBrokers, error: %{public}@", log: .error, error.localizedDescription)
            pixelHandler.fire(.generalError(error: error, functionOccurredIn: "DataBrokerProtectionBrokerUpdater.updateBrokers"))
            return
        }
        guard let brokers = brokers else { return }

        for broker in brokers {
            do {
                try update(broker)
            } catch {
                os_log("Error updating broker: %{public}@, with version: %{public}@", log: .dataBrokerProtection, broker.name, broker.version)
                pixelHandler.fire(.generalError(error: error, functionOccurredIn: "DataBrokerProtectionBrokerUpdater.updateBrokers"))
            }
        }
    }

    func checkForUpdatesInBrokerJSONFiles() {
        if let lastCheckedVersion = repository.getLastCheckedVersion() {
            if shouldUpdate(incoming: appVersion.versionNumber, storedVersion: lastCheckedVersion) {
                updateBrokersAndSaveLatestVersion()
            }
        } else {
            // There was not a last checked version. Probably new builds or ones without this new implementation
            // or user deleted user defaults.
            updateBrokersAndSaveLatestVersion()
        }
    }

    private func updateBrokersAndSaveLatestVersion() {
        repository.saveLatestAppVersionCheck(version: appVersion.versionNumber)
        updateBrokers()
    }

    // Here we check if we need to update broker files
    //
    // 1. We check if the broker exists in the database
    // 2. If does exist, we check the number version, if the version number is new, we update it
    // 3. If it does not exist, we add it, and we create the scan operations related to it
    private func update(_ broker: DataBroker) throws {
        guard let savedBroker = try vault.fetchBroker(with: broker.url) else {
            // The broker does not exist in the current storage. We need to add it.
            try add(broker)
            return
        }

        if shouldUpdate(incoming: broker.version, storedVersion: savedBroker.version) {
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

    private func shouldUpdate(incoming: String, storedVersion: String) -> Bool {
        let result = incoming.compare(storedVersion, options: .numeric)

        return result == .orderedDescending
    }
}

// MARK: - Testing and debug methods

extension DefaultDataBrokerProtectionBrokerUpdater: DataBrokerProtectionBrokerUpdaterDebugInterface {

    public static func provideForDebug() -> DefaultDataBrokerProtectionBrokerUpdater? {
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: DataBrokerProtectionSecureVaultErrorReporter.shared) {
            return DefaultDataBrokerProtectionBrokerUpdater(vault: vault)
        }

        os_log("Error when trying to create vault for data broker protection updater debug menu item", log: .dataBrokerProtection)
        return nil
    }

    public func replaceAllBrokersWithDebugBrokers() throws {
        try resources.removeExistingBrokersAndReplaceWithDebugBrokers()
    }
}

fileprivate extension URL {

    var isJSON: Bool {
        self.pathExtension.lowercased() == "json"
    }

    var hasFakePrefix: Bool {
        self.lastPathComponent.lowercased().hasPrefix("fake")
    }

    var isDebugBroker: Bool {
        self.lastPathComponent.lowercased() == "fakemyfakebroker.com.json"
    }
}
