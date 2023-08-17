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
    func fetchProfile() -> DataBrokerProtectionProfile?
    func fetchDataBrokerInfoData() -> [DataBrokerInfoData]
}

public protocol DataBrokerProtectionDataManagerDelegate: AnyObject {
    func dataBrokerProtectionDataManagerDidUpdateData()
}

public class DataBrokerProtectionDataManager: DataBrokerProtectionDataManaging {
    public weak var delegate: DataBrokerProtectionDataManagerDelegate?

    internal let database: DataBrokerProtectionRepository

    required public init(fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults()) {
        self.database = DataBrokerProtectionDataBase(fakeBrokerFlag: fakeBrokerFlag)
        setupNotifications()
    }

    public func saveProfile(_ profile: DataBrokerProtectionProfile) {
        database.save(profile)
    }

    public func fetchProfile() -> DataBrokerProtectionProfile? {
        if let profile = database.fetchProfile() {
            return profile
        } else {
            os_log("No profile found", log: .dataBrokerProtection)
            return nil
        }
    }

    public func fetchDataBrokerInfoData() -> [DataBrokerInfoData] {
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

        return result
    }

    @objc private func setupFakeData() {
        delegate?.dataBrokerProtectionDataManagerDidUpdateData()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(setupFakeData), name: DataBrokerProtectionNotifications.didFinishOptOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setupFakeData), name: DataBrokerProtectionNotifications.didFinishScan, object: nil)
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
