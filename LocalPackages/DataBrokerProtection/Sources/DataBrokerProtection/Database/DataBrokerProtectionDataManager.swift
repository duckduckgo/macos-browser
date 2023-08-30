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

public protocol DataBrokerProtectionDataManaging {
    var delegate: DataBrokerProtectionDataManagerDelegate? { get set }

    init(fakeBrokerFlag: FakeBrokerFlag)
    func saveProfile(_ profile: DataBrokerProtectionProfile)
    func fetchProfile(ignoresCache: Bool) -> DataBrokerProtectionProfile?
    func fetchDataBrokerInfoData(ignoresCache: Bool) -> [DataBrokerInfoData]
    func fetchBrokerProfileQueryData(ignoresCache: Bool) -> [BrokerProfileQueryData]
}

extension DataBrokerProtectionDataManaging {
    func fetchProfile() -> DataBrokerProtectionProfile? {
        fetchProfile(ignoresCache: false)
    }

    func fetchDataBrokerInfoData() -> [DataBrokerInfoData] {
        fetchDataBrokerInfoData(ignoresCache: false)
    }

    func fetchBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        fetchBrokerProfileQueryData(ignoresCache: false)
    }
}

public protocol DataBrokerProtectionDataManagerDelegate: AnyObject {
    func dataBrokerProtectionDataManagerDidUpdateData()
}

public class DataBrokerProtectionDataManager: DataBrokerProtectionDataManaging {
    private let cache = InMemoryDataCache()

    public weak var delegate: DataBrokerProtectionDataManagerDelegate?

    internal let database: DataBrokerProtectionRepository

    required public init(fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults()) {
        self.database = DataBrokerProtectionDatabase(fakeBrokerFlag: fakeBrokerFlag)
    }

    public func saveProfile(_ profile: DataBrokerProtectionProfile) {
        database.save(profile)
        cache.reset()
    }

    public func fetchProfile(ignoresCache: Bool = false) -> DataBrokerProtectionProfile? {
        if !ignoresCache, cache.profile != nil {
            os_log("Returning cached profile", log: .dataBrokerProtection)
            return cache.profile
        }

        if let profile = database.fetchProfile() {
            cache.profile = profile
            return profile
        } else {
            os_log("No profile found", log: .dataBrokerProtection)
            return nil
        }
    }

    public func fetchBrokerProfileQueryData(ignoresCache: Bool = false) -> [BrokerProfileQueryData] {
        if !ignoresCache, !cache.brokerProfileQueryData.isEmpty {
            os_log("Returning cached brokerProfileQueryData", log: .dataBrokerProtection)
            return cache.brokerProfileQueryData
        }

        let queryData = database.fetchAllBrokerProfileQueryData(for: 1) // We assume one profile for now
        cache.brokerProfileQueryData = queryData
        return queryData
    }

    public func fetchDataBrokerInfoData(ignoresCache: Bool = false) -> [DataBrokerInfoData] {
        if !ignoresCache, !cache.dataBrokerInfoData.isEmpty {
            os_log("Returning cached dataBrokerInfoData", log: .dataBrokerProtection)
            return cache.dataBrokerInfoData
        }

        let profileQueriesData = database.fetchAllBrokerProfileQueryData(for: 1) // We assume one profile for now
        let result = profileQueriesData.map { brokerProfileQuery in
            let scanData = DataBrokerInfoData.ScanData(historyEvents: brokerProfileQuery.scanOperationData.historyEvents,
                                                       preferredRunDate: brokerProfileQuery.scanOperationData.preferredRunDate)

            let optOutsData = brokerProfileQuery.optOutOperationsData.map {
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
        cache.dataBrokerInfoData = result
        return result
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

private final class InMemoryDataCache {
    var profile: DataBrokerProtectionProfile?
    var brokerProfileQueryData = [BrokerProfileQueryData]()
    var dataBrokerInfoData = [DataBrokerInfoData]()

    public func reset() {
        profile = nil
        brokerProfileQueryData.removeAll()
        dataBrokerInfoData.removeAll()
    }
}
