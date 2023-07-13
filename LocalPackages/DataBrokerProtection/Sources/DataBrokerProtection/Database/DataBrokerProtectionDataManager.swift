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

public protocol DataBrokerProtectionDataManagerDelegate: AnyObject {
    func dataBrokerProtectionDataManagerDidUpdateData()
}

public class DataBrokerProtectionDataManager {
    public weak var delegate: DataBrokerProtectionDataManagerDelegate?

    internal let database: DataBrokerProtectionDataBase
    private let userDataKey = "DataBrokerProtectionProfile"

    public init() {
        self.database = DataBrokerProtectionDataBase()
        setupNotifications()

    }

    public func saveProfile(_ profile: DataBrokerProtectionProfile) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: userDataKey)

            // Test
            self.database.testProfileQuery = profile.profileQueries.first
            database.setupFakeData()

        } catch {
            print("Error encoding profile: \(error)")
        }
    }

    public func fetchProfile() -> DataBrokerProtectionProfile? {
        if let data = UserDefaults.standard.data(forKey: userDataKey) {
            do {
                let decoder = JSONDecoder()
                let profile = try decoder.decode(DataBrokerProtectionProfile.self, from: data)

                // Test
                self.database.testProfileQuery = profile.profileQueries.first
                database.setupFakeData()

                return profile
            } catch {
                print("Error decoding profile: \(error)")
            }
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
