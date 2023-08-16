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

protocol DataBrokerProtectionRepository {
    func save(_ profile: DataBrokerProtectionProfile) throws // Is save the most representative name?

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData?
    func saveOperationData(_ data: BrokerOperationData)
    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData]
}

final class DataBrokerProtectionDatabase: DataBrokerProtectionRepository {
    // Data in memory for tests
    public var dataBrokers = [DataBroker]()
    public var brokerProfileQueriesData = [BrokerProfileQueryData]()
    public var testProfileQuery: ProfileQuery?

    private let fakeBrokerFlag: FakeBrokerFlag
    private let vault: (any DataBrokerProtectionSecureVault)?

    init(fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults(), vault: (any DataBrokerProtectionSecureVault)? = nil) {
        self.fakeBrokerFlag = fakeBrokerFlag
        self.vault = vault
    }

    /// This save function is more than a save, it initializes the profile and the profile queries. Should also initialize brokers?
    /// It also initializes the scans
    func save(_ profile: DataBrokerProtectionProfile) throws {
        let vault = try self.vault ?? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil)
        let brokers = try vault.fetchAllBrokers()
        let profileId = try vault.save(profile: profile)
        let profileQueries = profile.profileQueries

        // What about if brokers or profile queries are empty? Should we throw an error?

        for broker in brokers {
            guard let brokerId = broker.id else { continue } // What happens if a broker has a nil id? Should throw send a pixel or something?

            for profileQuery in profileQueries {
                let profileQueryId = try vault.save(profileQuery: profileQuery, profileId: profileId)
                try vault.save(brokerId: brokerId, profileQueryId: profileQueryId, lastRunDate: nil, preferredRunDate: nil)
            }
        }
    }

    func brokerProfileQueryData(for dataBrokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData? {
        return nil // TODO: We should check the database and return the correct broker profile query data
    }

    func saveOperationData(_ data: BrokerOperationData) {

    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        return brokerProfileQueriesData
    }

    func setupFakeData() {
        self.dataBrokers.removeAll()
        self.brokerProfileQueriesData.removeAll()

        var dataBroker: DataBroker

        if fakeBrokerFlag.isFakeBrokerFlagOn() {
            dataBroker = DataBroker.initFromResource("fake.verecor.com")
        } else {
            dataBroker = DataBroker.initFromResource("verecor.com")
        }

        let profileQuery = testProfileQuery!
        let queryData = BrokerProfileQueryData(dataBroker: dataBroker, profileQuery: profileQuery)

        self.dataBrokers.append(dataBroker)
        self.brokerProfileQueriesData.append(queryData)
    }
}
