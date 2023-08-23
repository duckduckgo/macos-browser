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
    func save(_ profile: DataBrokerProtectionProfile)
    func fetchProfile() -> DataBrokerProtectionProfile?

    func save(_ extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64
    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfileId: Int64)

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData?
    func fetchAllBrokerProfileQueryData(for profileId: Int64) -> [BrokerProfileQueryData]

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64)
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64)
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64)
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64)
    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64)

    func add(_ historyEvent: HistoryEvent)
    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) -> HistoryEvent?
}

final class DataBrokerProtectionDatabase: DataBrokerProtectionRepository {
    private let fakeBrokerFlag: FakeBrokerFlag
    private let vault: (any DataBrokerProtectionSecureVault)?

    init(fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults(), vault: (any DataBrokerProtectionSecureVault)? = nil) {
        self.fakeBrokerFlag = fakeBrokerFlag
        self.vault = vault
    }

    func save(_ profile: DataBrokerProtectionProfile) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            let brokers = try vault.fetchAllBrokers()
            let profileId = try vault.save(profile: profile)
            let profileQueries = profile.profileQueries

            // On the error handling task we should handle the work when the list of brokers or profile queries are empty.

            if brokers.isEmpty {
                let brokerId = try vault.save(broker: DataBroker.initFromResource("verecor.com"))

                for profileQuery in profileQueries {
                    let profileQueryId = try vault.save(profileQuery: profileQuery, profileId: profileId)
                    try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: nil)
                }
            } else {
                for broker in brokers {
                    guard let brokerId = broker.id else { continue } // What happens if a broker has a nil id? Should throw send a pixel or something?

                    for profileQuery in profileQueries {
                        let profileQueryId = try vault.save(profileQuery: profileQuery, profileId: profileId)
                        try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: nil)
                    }
                }
            }
        } catch {
            os_log("Database error: saveProfile, error: %{public}@", log: .error, error.localizedDescription)
        }
    }

    public func fetchProfile() -> DataBrokerProtectionProfile? {
        do {
            let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            return try vault.fetchProfile(with: 1)
        } catch {
            os_log("Database error: fetchProfile, error: %{public}@", log: .error, error.localizedDescription)
            return nil
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

    func fetchAllBrokerProfileQueryData(for profileId: Int64) -> [BrokerProfileQueryData] {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            let brokers = try vault.fetchAllBrokers()
            let profileQueries = try vault.fetchAllProfileQueries(for: profileId)
            var brokerProfileQueryDataList = [BrokerProfileQueryData]()

            for broker in brokers {
                for profileQuery in profileQueries {
                    if let brokerId = broker.id, let profileQueryId = profileQuery.id {
                        if let brokerProfileQueryData = brokerProfileQueryData(for: brokerId, and: profileQueryId) {
                            brokerProfileQueryDataList.append(brokerProfileQueryData)
                        }
                    }
                }
            }

            return brokerProfileQueryDataList
        } catch {
            os_log("Database error: fetchAllBrokerProfileQueryData, error: %{public}@", log: .error, error.localizedDescription)
            return [BrokerProfileQueryData]()
        }
    }

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfileId: Int64) {
        do {
            let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

            try vault.save(brokerId: optOut.brokerId,
                           profileQueryId: optOut.profileQueryId,
                           extractedProfileId: extractedProfileId,
                           lastRunDate: optOut.lastRunDate,
                           preferredRunDate: optOut.preferredRunDate)
        } catch {
            os_log("Database error: saveOptOutOperation, error: %{public}@", log: .error, error.localizedDescription)
        }
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
}
