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
    func save(_ profile: DataBrokerProtectionProfile) async throws
    func fetchProfile() throws -> DataBrokerProtectionProfile?
    func deleteProfileData() throws

    func fetchChildBrokers(for parentBroker: String) throws -> [DataBroker]

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) throws -> BrokerProfileQueryData?
    func fetchAllBrokerProfileQueryData() throws -> [BrokerProfileQueryData]
    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfile]

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64) throws

    func add(_ historyEvent: HistoryEvent) throws
    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) throws -> HistoryEvent?
    func hasMatches() throws -> Bool

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation?
    func addAttempt(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws
}

final class DataBrokerProtectionDatabase: DataBrokerProtectionRepository {
    private static let profileId: Int64 = 1 // At the moment, we only support one profile for DBP.

    private let fakeBrokerFlag: DataBrokerDebugFlag
    private let vault: (any DataBrokerProtectionSecureVault)?

    init(fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker(), vault: (any DataBrokerProtectionSecureVault)? = nil) {
        self.fakeBrokerFlag = fakeBrokerFlag
        self.vault = vault
    }

    func save(_ profile: DataBrokerProtectionProfile) async throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        if try vault.fetchProfile(with: Self.profileId) != nil {
            try await updateProfile(profile, vault: vault)
        } else {
            try await saveNewProfile(profile, vault: vault)
        }
    }

    public func fetchProfile() throws -> DataBrokerProtectionProfile? {
        let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        return try vault.fetchProfile(with: Self.profileId)
    }

    public func deleteProfileData() throws {
        let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        try vault.deleteProfileData()
    }

    func fetchChildBrokers(for parentBroker: String) throws -> [DataBroker] {
        let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        return try vault.fetchChildBrokers(for: parentBroker)
    }

    func save(_ extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64 {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        return try vault.save(extractedProfile: extractedProfile, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) throws -> BrokerProfileQueryData? {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        guard let broker = try vault.fetchBroker(with: brokerId),
              let profileQuery = try vault.fetchProfileQuery(with: profileQueryId),
              let scanOperation = try vault.fetchScan(brokerId: brokerId, profileQueryId: profileQueryId) else {
            // TODO perhaps this should error if we query for things that don't exist?
            return nil
        }

        let optOutOperations = try vault.fetchOptOuts(brokerId: brokerId, profileQueryId: profileQueryId)

        return BrokerProfileQueryData(
            dataBroker: broker,
            profileQuery: profileQuery,
            scanOperationData: scanOperation,
            optOutOperationsData: optOutOperations
        )
    }

    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfile] {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        return try vault.fetchExtractedProfiles(for: brokerId)
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        try vault.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        try vault.updatePreferredRunDate(
            date,
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            extractedProfileId: extractedProfileId)
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        try vault.updateLastRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        try vault.updateLastRunDate(
            date,
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            extractedProfileId: extractedProfileId
        )
    }

    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        try vault.updateRemovedDate(for: extractedProfileId, with: date)
    }

    func add(_ historyEvent: HistoryEvent) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        if  let extractedProfileId = historyEvent.extractedProfileId {
            try vault.save(historyEvent: historyEvent, brokerId: historyEvent.brokerId, profileQueryId: historyEvent.profileQueryId, extractedProfileId: extractedProfileId)
        } else {
            try vault.save(historyEvent: historyEvent, brokerId: historyEvent.brokerId, profileQueryId: historyEvent.profileQueryId)
        }
    }

    func fetchAllBrokerProfileQueryData() throws -> [BrokerProfileQueryData] {
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
    }

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        try vault.save(brokerId: optOut.brokerId,
                       profileQueryId: optOut.profileQueryId,
                       extractedProfile: extractedProfile,
                       lastRunDate: optOut.lastRunDate,
                       preferredRunDate: optOut.preferredRunDate)
    }

    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) throws -> HistoryEvent? {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        let events = try vault.fetchEvents(brokerId: brokerId, profileQueryId: profileQueryId)

        return events.max(by: { $0.date < $1.date })
    }

    func hasMatches() throws -> Bool {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        return try vault.hasMatches()
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation? {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.fetchAttemptInformation(for: extractedProfileId)
        } catch {
            os_log("Database error: fetchAttemptInformation, error: %{public}@", log: .error, error.localizedDescription)
            return nil
        }
    }

    func addAttempt(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        try vault.save(extractedProfileId: extractedProfileId,
                       attemptUUID: attemptUUID,
                       dataBroker: dataBroker,
                       lastStageDate: lastStageDate,
                       startTime: startTime)
    }
}

// Private Methods
extension DataBrokerProtectionDatabase {

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
                try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: Date())
            }
        }
    }

    private func saveNewProfile(_ profile: DataBrokerProtectionProfile, vault: any DataBrokerProtectionSecureVault) async throws {
        let newProfileQueries = profile.profileQueries
        _ = try vault.save(profile: profile)

        if let brokers = try FileResources().fetchBrokerFromResourceFiles() {
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

        let databaseBrokerProfileQueryData = try fetchAllBrokerProfileQueryData()
        let databaseProfileQueries = databaseBrokerProfileQueryData.map { $0.profileQuery }

        // The queries we need to create are the one that exist on the new ones but not in the database
        var profileQueriesToCreate = Set(newProfileQueries).subtracting(Set(databaseProfileQueries))

        // The queries that need update exist in both the new and the database
        // We assume updated queries will be not deprecated
        var profileQueriesToUpdate = Array(Set(databaseProfileQueries).intersection(Set(newProfileQueries))).map {
            $0.with(deprecated: false)
        }
        // The ones that we need to remove are the ones that exist in the database but not in the new ones
        var profileQueriesToRemove = Set(databaseProfileQueries).subtracting(Set(newProfileQueries))

        // For the profile queries we are going to remove. We need to check if they have extracted profiles.
        // If the profile query has matches, we need to set it as deprecated and add it to the updates profile
        // we also need to remove it from the profile queries to remove.
        for brokerProfileQueryData in databaseBrokerProfileQueryData where profileQueriesToRemove.contains(brokerProfileQueryData.profileQuery) {
            if brokerProfileQueryData.hasMatches {
                let deprecatedProfileQuery = brokerProfileQueryData.profileQuery.with(deprecated: true)
                profileQueriesToUpdate.append(deprecatedProfileQuery)
                profileQueriesToRemove.remove(brokerProfileQueryData.profileQuery)
            }
        }

        let profileID = try vault.update(profile: profile)
        let brokerIDs = try vault.fetchAllBrokers().compactMap({ $0.id })

        // Delete
        if !profileQueriesToRemove.isEmpty {
            try deleteProfileQueries(Array(profileQueriesToRemove),
                                     profileID: profileID,
                                     vault: vault)
        }

        // Update profileQueries
        if !profileQueriesToUpdate.isEmpty {
            try updateProfileQueries(Array(profileQueriesToUpdate),
                                     profileID: profileID,
                                     brokerIDs: brokerIDs,
                                     vault: vault)
        }

        // Create
        if !profileQueriesToCreate.isEmpty {
            try initializeDatabaseForProfile(
                profileId: Self.profileId,
                vault: vault,
                brokerIDs: brokerIDs,
                profileQueries: Array(profileQueriesToCreate)
            )
        }
    }

    private func deleteProfileQueries(_ profileQueries: [ProfileQuery],
                                      profileID: Int64,
                                      vault: any DataBrokerProtectionSecureVault) throws {

        for profile in profileQueries {
            try vault.delete(profileQuery: profile, profileId: profileID)
        }
    }

    private func updateProfileQueries(_ profileQueries: [ProfileQuery],
                                      profileID: Int64,
                                      brokerIDs: [Int64],
                                      vault: any DataBrokerProtectionSecureVault) throws {

        for profile in profileQueries {
            let profileQueryID = try vault.update(profile,
                                                  brokerIDs: brokerIDs,
                                                  profileId: profileID)

            if !profile.deprecated {
                for brokerID in brokerIDs where !profile.deprecated {
                    try updatePreferredRunDate(Date(), brokerId: brokerID, profileQueryId: profileQueryID)
                }
            }
        }
    }
}
