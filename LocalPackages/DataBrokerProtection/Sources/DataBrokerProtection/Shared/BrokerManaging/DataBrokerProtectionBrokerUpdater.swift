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
import AppKitExtensions
import Cocoa
import SecureStorage
import os.log

protocol ResourcesRepository {
    func fetchBrokerFromResourceFiles() throws -> [DataBroker]?
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
        guard NSApplication.runType != .unitTests && NSApplication.runType != .uiTests else {
            /*
             There's a bug with the bundle resources in tests:
             https://forums.swift.org/t/swift-5-3-swiftpm-resources-in-tests-uses-wrong-bundle-path/37051/49
             */
            return []
        }

        guard let resourceURL = Bundle.module.resourceURL else {
            Logger.dataBrokerProtection.fault("DataBrokerProtectionUpdater: error FileResources fetchBrokerFromResourceFiles, error: Bundle.module.resourceURL is nil")
            assertionFailure()
            throw FileResourcesError.bundleResourceURLNil
        }

        let shouldUseFakeBrokers = (NSApp.runType == .integrationTests)
        let brokersURL = resourceURL.appendingPathComponent("Resources").appendingPathComponent("JSON")
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: brokersURL,
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
            Logger.dataBrokerProtection.error("DataBrokerProtectionUpdater: error FileResources error: fetchBrokerFromResourceFiles, error: \(error.localizedDescription, privacy: .public)")
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

protocol DataBrokerProtectionBrokerUpdater {
    static func provideForDebug() -> DefaultDataBrokerProtectionBrokerUpdater?
    func updateBrokers()
    func checkForUpdatesInBrokerJSONFiles()
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

    public static func provideForDebug() -> DefaultDataBrokerProtectionBrokerUpdater? {
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: DataBrokerProtectionSecureVaultErrorReporter.shared) {
            return DefaultDataBrokerProtectionBrokerUpdater(vault: vault)
        }

        Logger.dataBrokerProtection.log("Error when trying to create vault for data broker protection updater debug menu item")
        return nil
    }

    public func updateBrokers() {
        let brokers: [DataBroker]?
        do {
            brokers = try resources.fetchBrokerFromResourceFiles()
        } catch {
            Logger.dataBrokerProtection.error("DataBrokerProtectionBrokerUpdater updateBrokers, error: \(error.localizedDescription, privacy: .public)")
            pixelHandler.fire(.cocoaError(error: error, functionOccurredIn: "DataBrokerProtectionBrokerUpdater.updateBrokers"))
            return
        }
        guard let brokers = brokers else { return }

        for broker in brokers {
            do {
                try update(broker)
            } catch {
                Logger.dataBrokerProtection.log("Error updating broker: \(broker.name, privacy: .public), with version: \(broker.version, privacy: .public)")
                pixelHandler.fire(.databaseError(error: error, functionOccurredIn: "DataBrokerProtectionBrokerUpdater.updateBrokers"))
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
            try updateAttemptCount(broker)
        }
    }

    private func updateAttemptCount(_ broker: DataBroker) throws {
        guard broker.type == .parent, let brokerId = broker.id else { return }

        let optOutJobs = try vault.fetchOptOuts(brokerId: brokerId)
        for optOutJob in optOutJobs {
            if let extractedProfileId = optOutJob.extractedProfile.id {
                try vault.updateAttemptCount(0, brokerId: brokerId, profileQueryId: optOutJob.profileQueryId, extractedProfileId: extractedProfileId)
            }
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

fileprivate extension URL {

    var isJSON: Bool {
        self.pathExtension.lowercased() == "json"
    }

    var hasFakePrefix: Bool {
        self.lastPathComponent.lowercased().hasPrefix("fake")
    }
}
