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

public struct DataBrokerProtectionDataManager {
    internal let database: DataBrokerProtectionDataBase
    private let userDataKey = "DataBrokerProtectionProfile"

    public init() {
        self.database = DataBrokerProtectionDataBase()
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
}
