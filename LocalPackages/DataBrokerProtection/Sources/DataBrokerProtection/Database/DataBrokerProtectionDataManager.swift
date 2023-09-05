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
    func saveProfile(_ profile: DataBrokerProtectionProfile) async
    func fetchProfile(ignoresCache: Bool) -> DataBrokerProtectionProfile?
    func fetchBrokerProfileQueryData(ignoresCache: Bool) -> [BrokerProfileQueryData]
}

extension DataBrokerProtectionDataManaging {
    func fetchProfile() -> DataBrokerProtectionProfile? {
        fetchProfile(ignoresCache: false)
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

    public func saveProfile(_ profile: DataBrokerProtectionProfile) async {
        await database.save(profile)
        cache.invalidate()
        cache.profile = profile
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
}

private final class InMemoryDataCache {
    var profile: DataBrokerProtectionProfile?
    var brokerProfileQueryData = [BrokerProfileQueryData]()

    public func invalidate() {
        profile = nil
        brokerProfileQueryData.removeAll()
    }
}
