//
//  DataBrokerProtectionDataManager.swift
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

public protocol DataBrokerProtectionDataManagerDelegate: AnyObject {
    func dataBrokerProtectionDataManagerDidUpdateData()
}

public class DataBrokerProtectionDataManager {
    public weak var delegate: DataBrokerProtectionDataManagerDelegate?

    internal let database: DataBrokerProtectionDataBase

    public init(fakeBrokerFlag: FakeBrokerFlag) {
        self.database = DataBrokerProtectionDataBase(fakeBrokerFlag: fakeBrokerFlag)
        setupNotifications()
    }

    public func saveProfile(_ profile: DataBrokerProtectionProfile) {
        // Setup the fakes data
        self.database.testProfileQuery = profile.profileQueries.first
        self.database.setupFakeData()

        // Saves profile in the secure database
        do {
            let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            let profileId = try vault.save(profile: profile)
            try saveSchedulerData(with: profileId)
        } catch {
            os_log("ERROR: Secure storage \(error)", log: .error)
        }
    }

    public func fetchProfile() -> DataBrokerProtectionProfile? {
        do {
            let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
            if let profile = try vault.fetchProfile(with: 1) {
                try testFetchingSchedulerData()
                return profile
            } else {
                os_log("No profile found", log: .dataBrokerProtection)
            }
        } catch {
            os_log("ERROR: Secure storage \(error)", log: .error)
        }

        return nil
    }

    public func fetchDataBrokerInfoData() -> [DataBrokerInfoData] {
        let profileQueriesData = database.brokerProfileQueriesData
        let result = profileQueriesData.map { brokerProfileQuery in
            let scanData = DataBrokerInfoData.ScanData(historyEvents: brokerProfileQuery.scanData.historyEvents,
                                                       preferredRunDate: brokerProfileQuery.scanData.preferredRunDate)

            let optOutsData = brokerProfileQuery.optOutsData.map {
                DataBrokerInfoData.OptOutData(historyEvents: $0.historyEvents,
                                              extractedProfileName: $0.extractedProfile.name ?? "No name",
                                              preferredRunDate: $0.preferredRunDate)
            }

            return DataBrokerInfoData(userFirstName: brokerProfileQuery.profileQuery.firstName,
                                      userLastName: brokerProfileQuery.profileQuery.lastName,
                                      dataBrokerName: brokerProfileQuery.dataBroker.name,
                                      scanData: scanData,
                                      optOutsData: optOutsData)
        }
        return result
    }

    @objc private func setupFakeData() {
        delegate?.dataBrokerProtectionDataManagerDidUpdateData()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(setupFakeData), name: DataBrokerProtectionNotifications.didFinishOptOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setupFakeData), name: DataBrokerProtectionNotifications.didFinishScan, object: nil)
    }

    // ℹ️ This method was added for testing purposes and to ease the code review. Will be deleted before merging.
    //
    // After a profile is inserted. It simulates a scan followed by an optout.
    // 1. It creates two brokers: Peoplefinders and Verecor
    // 2. Fetches the profile with the provided profileId, and uses the first name and address to create a ProfileQuery
    // 3. We combine the profileQuery with the two brokers to create two scan rows
    // 4. We simulate that scans have started. After 2 seconds, we simulate that we found matches on Verecor and no matches on Peoplefinders
    // 5. We insert the two found profiles into the ExtractedProfile table
    // 6. We create the two optOut operations inserting the rows into the OptOut table
    // 7. We simulate the optOut process. The first extracted profile is remove successfully, the second one fails with error
    func saveSchedulerData(with profileId: Int64) throws {
        let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        let peopleFindersId = try vault.save(broker: DataBroker.initFromResource("peoplefinders.com"))
        let verecorId = try vault.save(broker: DataBroker.initFromResource("verecor.com"))
        if let profile = try vault.fetchProfile(with: 1) {
            let profileQueries = profile.profileQueries
            for profileQuery in profileQueries {
                let profileQueryId = try vault.save(profileQuery: profileQuery, profileId: profileId)
                try vault.save(brokerId: peopleFindersId, profileQueryId: profileQueryId, lastRunDate: Date(), preferredRunDate: Date())
                try vault.save(brokerId: verecorId, profileQueryId: profileQueryId, lastRunDate: Date(), preferredRunDate: Date())
                try vault.save(historyEvent: .init(type: .scanStarted), brokerId: peopleFindersId, profileQueryId: profileQueryId)
                try vault.save(historyEvent: .init(type: .scanStarted), brokerId: verecorId, profileQueryId: profileQueryId)
                sleep(1)
                try vault.save(historyEvent: .init(type: .noMatchFound), brokerId: peopleFindersId, profileQueryId: profileQueryId)
                try vault.save(historyEvent: .init(type: .matchFound(extractedProfileID: UUID())), brokerId: verecorId, profileQueryId: profileQueryId)
                sleep(1)
                let firstExtractedProfileId = try vault.save(extractedProfile: ExtractedProfile(name: "Juan Pereira"), brokerId: verecorId, profileQueryId: profileQueryId)
                let secondExtractedProfileId = try vault.save(extractedProfile: ExtractedProfile(name: "Juan Manuel Pereira"), brokerId: verecorId, profileQueryId: profileQueryId)
                try vault.save(brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: firstExtractedProfileId, lastRunDate: Date(), preferredRunDate: Date())
                try vault.save(brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: secondExtractedProfileId, lastRunDate: Date(), preferredRunDate: Date())
                sleep(1)
                try vault.save(historyEvent: .init(type: .optOutStarted(extractedProfileID: UUID())), brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: firstExtractedProfileId)
                try vault.save(historyEvent: .init(type: .optOutStarted(extractedProfileID: UUID())), brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: secondExtractedProfileId)
                sleep(1)
                try vault.save(historyEvent: .init(type: .optOutRequested(extractedProfileID: UUID())), brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: firstExtractedProfileId)
                try vault.save(historyEvent: .init(type: .error(error: DataBrokerProtectionError.unknown(""))), brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: secondExtractedProfileId)
                sleep(1)
                try vault.save(historyEvent: .init(type: .optOutConfirmed(extractedProfileID: UUID())), brokerId: verecorId, profileQueryId: profileQueryId, extractedProfileId: firstExtractedProfileId)
            }
        }
    }

    // ℹ️ This method was added for testing purposes and to ease the code review. Will be deleted before merging.
    //
    // This method is a helper for saveSchedulerData, to check the data being saved is correctly fetched and unencrypted/decoded
    private func testFetchingSchedulerData() throws {
        let vault = try DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)

        let profileQueryId: Int64 = 1
        let peopleFindersId: Int64 = 1
        let verecorId: Int64 = 2

        let extractedProfilesPeopleFinders = try vault.fetchExtractedProfiles(for: peopleFindersId, with: profileQueryId)
        let extractedProfilesVerecor = try vault.fetchExtractedProfiles(for: verecorId, with: profileQueryId)
        let scans = try vault.fetchAllScans()
        let optOuts = try vault.fetchAllOptOuts()
        let peopleFindersEvents = try vault.fetchEvents(brokerId: peopleFindersId, profileQueryId: profileQueryId)
        let verecorEvents = try vault.fetchEvents(brokerId: verecorId, profileQueryId: profileQueryId)

        print("Debug")
    }
}

public struct DataBrokerInfoData: Identifiable {
    public struct ScanData: Identifiable {
        public let id = UUID()
        public let historyEvents: [HistoryEvent]
        public let preferredRunDate: Date?
    }

    public struct OptOutData: Identifiable {
        public let id = UUID()
        public let historyEvents: [HistoryEvent]
        public let extractedProfileName: String
        public let preferredRunDate: Date?
    }

    public let id = UUID()
    public let userFirstName: String
    public let userLastName: String
    public let dataBrokerName: String
    public let scanData: ScanData
    public let optOutsData: [OptOutData]
}
