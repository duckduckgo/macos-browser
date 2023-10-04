//
//  DataBrokerProtectionDatabase.swift
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

protocol DataBrokerProtectionRepository {
    func save(_ profile: DataBrokerProtectionProfile) async
    func fetchProfile() -> DataBrokerProtectionProfile?

    func fetchChildBrokers(for parentBroker: String) -> [DataBroker]

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData?
    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData]
    func fetchExtractedProfiles(for brokerId: Int64) -> [ExtractedProfile]

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64)
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64)
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64)
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64)
    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64)

    func add(_ historyEvent: HistoryEvent)
    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) -> HistoryEvent?
    func hasMatches() -> Bool

    func fetchAttemptInformation(for extractedProfileId: Int64) -> AttemptInformation?
    func addAttempt(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date)
}

final class DataBrokerProtectionDatabase: DataBrokerProtectionRepository {
    private static let profileId: Int64 = 1 // At the moment, we only support one profile for DBP.

    private let fakeBrokerFlag: DataBrokerDebugFlag
    private let vault: (any DataBrokerProtectionSecureVault)?

    init(fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker(), vault: (any DataBrokerProtectionSecureVault)? = nil) {
        self.fakeBrokerFlag = fakeBrokerFlag
        self.vault = vault
    }

    func save(_ profile: DataBrokerProtectionProfile) async {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            if try vault.fetchProfile(with: Self.profileId) != nil {
                try await updateProfile(profile, vault: vault)
            } else {
                try await saveNewProfile(profile, vault: vault)
            }
        } catch {
            os_log("Database error: saveProfile, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    private func initializeDatabaseForProfile(profileId: Int64,
                                              vault: any (DataBrokerProtectionSecureVault),
                                              brokerIDs: [Int64],
                                              profileQueries: [ProfileQuery]) throws {
        var profileQueryIDs = [Int64]()

        for profileQuery in profileQueries {
            let profileQueryId = try vault.save(profileQuery: profileQuery, profileId: profileId)
            profileQueryIDs.append(profileQueryId)
        }

        for brokerId in brokerIDs {
            for profileQueryId in profileQueryIDs {
                try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: nil)
            }
        }
    }

    public func fetchProfile() -> DataBrokerProtectionProfile? {
        do {
            let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.fetchProfile(with: Self.profileId)
        } catch {
            os_log("Database error: fetchProfile, error: %{public}@", log: .error, error.localizedDescription)
            return nil
        }
    }

    func fetchChildBrokers(for parentBroker: String) -> [DataBroker] {
        do {
            let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.fetchChildBrokers(for: parentBroker)
        } catch {
            os_log("Database error: fetchChildBrokers, error: %{public}@", log: .error, error.localizedDescription)
            return [DataBroker]()
        }
    }

    func save(_ extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64 {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        return try vault.save(extractedProfile: extractedProfile, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData? {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            if let broker = try vault.fetchBroker(with: brokerId),
                let profileQuery = try vault.fetchProfileQuery(with: profileQueryId),
                let scanOperation = try vault.fetchScan(brokerId: brokerId, profileQueryId: profileQueryId) {

                let optOutOperations = try vault.fetchOptOuts(brokerId: brokerId, profileQueryId: profileQueryId)

                return BrokerProfileQueryData(
                    dataBroker: broker,
                    profileQuery: profileQuery,
                    scanOperationData: scanOperation,
                    optOutOperationsData: optOutOperations
                )
            } else {
                // We should throw here. The caller probably needs to know that some of the
                // models he was looking for where not found. This will be worked on the error handling task/project.
                return nil
            }
        } catch {
            os_log("Database error: brokerProfileQueryData, error: %{public}@", log: .error, error.localizedDescription)
            return nil
        }
    }

    func fetchExtractedProfiles(for brokerId: Int64) -> [ExtractedProfile] {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            return try vault.fetchExtractedProfiles(for: brokerId)
        } catch {
            os_log("Database error: fetchExtractedProfiles for scan, error: %{public}@", log: .error, error.localizedDescription)
            return [ExtractedProfile]()
        }
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
        } catch {
            os_log("Database error: updatePreferredRunDate for scan, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.updatePreferredRunDate(
                date,
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId
            )
        } catch {
            os_log("Database error: updatePreferredRunDate for optOut, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.updateLastRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
        } catch {
            os_log("Database error: updateLastRunDate for scan, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.updateLastRunDate(
                date,
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId
            )
        } catch {
            os_log("Database error: updateLastRunDate for optOut, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.updateRemovedDate(for: extractedProfileId, with: date)
        } catch {
            os_log("Database error: updateRemoveDate, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func add(_ historyEvent: HistoryEvent) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            if  let extractedProfileId = historyEvent.extractedProfileId {
                try vault.save(historyEvent: historyEvent, brokerId: historyEvent.brokerId, profileQueryId: historyEvent.profileQueryId, extractedProfileId: extractedProfileId)
            } else {
                try vault.save(historyEvent: historyEvent, brokerId: historyEvent.brokerId, profileQueryId: historyEvent.profileQueryId)
            }
        } catch {
            os_log("Database error: addHistoryEvent, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            let brokers = try vault.fetchAllBrokers()
            let profileQueries = try vault.fetchAllProfileQueries(for: Self.profileId)
            var brokerProfileQueryDataList = [BrokerProfileQueryData]()

            for broker in brokers {
                for profileQuery in profileQueries {
                    if let brokerId = broker.id, let profileQueryId = profileQuery.id {
                        guard let scanOperation = try vault.fetchScan(brokerId: brokerId, profileQueryId: profileQueryId) else { continue }
                        let optOutOperations = try vault.fetchOptOuts(brokerId: brokerId, profileQueryId: profileQueryId)

                        let brokerProfileQueryData = BrokerProfileQueryData(
                            dataBroker: broker,
                            profileQuery: profileQuery,
                            scanOperationData: scanOperation,
                            optOutOperationsData: optOutOperations
                        )

                        brokerProfileQueryDataList.append(brokerProfileQueryData)
                    }
                }
            }

            return brokerProfileQueryDataList
        } catch {
            os_log("Database error: fetchAllBrokerProfileQueryData, error: %{public}@", log: .error, error.localizedDescription)
            return [BrokerProfileQueryData]()
        }
    }

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        try vault.save(brokerId: optOut.brokerId,
                       profileQueryId: optOut.profileQueryId,
                       extractedProfile: extractedProfile,
                       lastRunDate: optOut.lastRunDate,
                       preferredRunDate: optOut.preferredRunDate)
    }

    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) -> HistoryEvent? {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            let events = try vault.fetchEvents(brokerId: brokerId, profileQueryId: profileQueryId)

            return events.max(by: { $0.date < $1.date })
        } catch {
            os_log("Database error: fetchLastEvent, error: %{public}@", log: .error, error.localizedDescription)
            return nil
        }
    }

    func hasMatches() -> Bool {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.hasMatches()
        } catch {
            os_log("Database error: wereThereAnyMatches, error: %{public}@", log: .error, error.localizedDescription)
            return false
        }
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) -> AttemptInformation? {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.fetchAttemptInformation(for: extractedProfileId)
        } catch {
            os_log("Database error: fetchAttemptInformation, error: %{public}@", log: .error, error.localizedDescription)
            return nil
        }
    }

    func addAttempt(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            try vault.save(extractedProfileId: extractedProfileId,
                           attemptUUID: attemptUUID,
                           dataBroker: dataBroker,
                           lastStageDate: lastStageDate,
                           startTime: startTime)
        } catch {
            os_log("Database error: addAttempt, error: %{public}@", log: .error, error.localizedDescription)
        }
    }
}

// Private Methods
extension DataBrokerProtectionDatabase {

    private func saveNewProfile(_ profile: DataBrokerProtectionProfile, vault: any DataBrokerProtectionSecureVault) async throws {
        let newProfileQueries = profile.profileQueries
        _ = try vault.save(profile: profile)

        if let brokers = FileResources().fetchBrokerFromResourceFiles() {
            var brokerIDs = [Int64]()

            for broker in brokers {
                let brokerId = try vault.save(broker: broker)
                brokerIDs.append(brokerId)
            }

            try initializeDatabaseForProfile(
                profileId: Self.profileId,
                vault: vault,
                brokerIDs: brokerIDs,
                profileQueries: newProfileQueries
            )
        }
    }

    // https://app.asana.com/0/481882893211075/1205574642847432/f
    private func updateProfile(_ profile: DataBrokerProtectionProfile, vault: any DataBrokerProtectionSecureVault) async throws {
        let newProfileQueries = profile.profileQueries

        var profileQueriesToCreate = [ProfileQuery]()
        var profileQueriesToRemove = [ProfileQuery]()

        let databaseBrokerProfileQueryData = fetchAllBrokerProfileQueryData()
        let databaseProfileQueries = databaseBrokerProfileQueryData.map { $0.profileQuery }
        // Create hash for profileQuery: brokerProfileQuery to make the search easier/faster

        for profileQuery in newProfileQueries {
            if databaseProfileQueries.contains(profileQuery) {
                // If the DB contains this profileQuery, it means the user is adding the same name back again
                // In this case we remove the deprecated flag
                let reAddedProfileQuery = profileQuery.withDeprecationFlag(deprecated: false)
                profileQueriesToCreate.append(reAddedProfileQuery)
            } else {
                profileQueriesToCreate.append(profileQuery)
            }
        }

        for profileQuery in databaseProfileQueries where !newProfileQueries.contains(profileQuery) {
            if let brokerProfileQueryData = databaseBrokerProfileQueryData.filter({ $0.profileQuery == profileQuery }).first, !brokerProfileQueryData.extractedProfiles.isEmpty {
                let deprecatedProfileQuery = brokerProfileQueryData.profileQuery.withDeprecationFlag(deprecated: true)
                profileQueriesToCreate.append(deprecatedProfileQuery)
            } else {
                profileQueriesToRemove.append(profileQuery)
            }
        }

        let profileID = try vault.update(profile: profile)
        let brokerIDs = try vault.fetchAllBrokers().compactMap({ $0.id })

        try deleteProfileQueries(profileQueriesToRemove, profileID: profileID, vault: vault)
        // Update profileQueries
        // Create profileQueries

        try initializeDatabaseForProfile(
            profileId: Self.profileId,
            vault: vault,
            brokerIDs: brokerIDs,
            profileQueries: newProfileQueries
        )
    }

    private func deleteProfileQueries(_ profileQueries: [ProfileQuery],
                                      profileID: Int64,
                                      vault: any DataBrokerProtectionSecureVault) throws {

        for profile in profileQueries {
            try vault.delete(profileQuery: profile, profileId: profileID)
        }
    }
}
