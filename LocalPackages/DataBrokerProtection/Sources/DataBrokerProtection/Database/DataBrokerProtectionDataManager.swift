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
    var cache: InMemoryDataCache { get }
    var delegate: DataBrokerProtectionDataManagerDelegate? { get set }

    init(fakeBrokerFlag: DataBrokerDebugFlag)
    func saveProfile(_ profile: DataBrokerProtectionProfile) async -> Bool
    func fetchProfile(ignoresCache: Bool) -> DataBrokerProtectionProfile?
    func fetchBrokerProfileQueryData(ignoresCache: Bool) async -> [BrokerProfileQueryData]
    func hasMatches() -> Bool
}

extension DataBrokerProtectionDataManaging {
    func fetchProfile() -> DataBrokerProtectionProfile? {
        fetchProfile(ignoresCache: false)
    }

    func fetchBrokerProfileQueryData() async -> [BrokerProfileQueryData] {
        await fetchBrokerProfileQueryData(ignoresCache: false)
    }
}

public protocol DataBrokerProtectionDataManagerDelegate: AnyObject {
    func dataBrokerProtectionDataManagerDidUpdateData()
    func dataBrokerProtectionDataManagerDidDeleteData()
}

public class DataBrokerProtectionDataManager: DataBrokerProtectionDataManaging {
    public let cache = InMemoryDataCache()

    public weak var delegate: DataBrokerProtectionDataManagerDelegate?

    internal let database: DataBrokerProtectionRepository

    required public init(fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()) {
        self.database = DataBrokerProtectionDatabase(fakeBrokerFlag: fakeBrokerFlag)

        cache.delegate = self
    }

    public func saveProfile(_ profile: DataBrokerProtectionProfile) async -> Bool {
        let result = await database.save(profile)
        cache.invalidate()
        cache.profile = profile

        return result
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

    public func fetchBrokerProfileQueryData(ignoresCache: Bool = false) async -> [BrokerProfileQueryData] {
        if !ignoresCache, !cache.brokerProfileQueryData.isEmpty {
            os_log("Returning cached brokerProfileQueryData", log: .dataBrokerProtection)
            return cache.brokerProfileQueryData
        }

        let queryData = database.fetchAllBrokerProfileQueryData()
        cache.brokerProfileQueryData = queryData
        return queryData
    }

    public func hasMatches() -> Bool {
        return database.hasMatches()
    }
}

extension DataBrokerProtectionDataManager: InMemoryDataCacheDelegate {
    public func flushCache(profile: DataBrokerProtectionProfile?) async -> Bool {
        guard let profile = profile else { return false }
        let result = await saveProfile(profile)

        delegate?.dataBrokerProtectionDataManagerDidUpdateData()

        return result
    }

    public func removeAllData() {
        database.deleteProfileData()
        cache.invalidate()

        delegate?.dataBrokerProtectionDataManagerDidDeleteData()
    }
}

public protocol InMemoryDataCacheDelegate: AnyObject {
    func flushCache(profile: DataBrokerProtectionProfile?) async -> Bool
    func removeAllData()
}

public final class InMemoryDataCache {
    var profile: DataBrokerProtectionProfile?
    var brokerProfileQueryData = [BrokerProfileQueryData]()
    private let mapper = MapperToUI()

    weak var delegate: InMemoryDataCacheDelegate?
    weak var scanDelegate: DBPUIScanOps?

    private let emptyProfile: DataBrokerProtectionProfile = {
        DataBrokerProtectionProfile(names: [], addresses: [], phones: [], birthYear: -1)
    }()

    public func invalidate() {
        profile = nil
        brokerProfileQueryData.removeAll()
    }
}

extension InMemoryDataCache: DBPUICommunicationDelegate {
    func saveProfile() async -> Bool {
        _ = await delegate?.flushCache(profile: profile)

        return true
    }

    private func indexForName(matching name: DBPUIUserProfileName, in profile: DataBrokerProtectionProfile) -> Int? {
        if let idx = profile.names.firstIndex(where: { $0.firstName == name.first && $0.lastName == name.last && $0.middleName == name.middle && $0.suffix == name.suffix }) {
            return idx
        }

        return nil
    }

    private func indexForAddress(matching address: DBPUIUserProfileAddress, in profile: DataBrokerProtectionProfile) -> Int? {
        if let idx = profile.addresses.firstIndex(where: { $0.street == address.street && $0.state == address.state && $0.city == address.city && $0.zipCode == address.zipCode}) {
            return idx
        }

        return nil
    }

    private func isNameEmpty(_ name: DBPUIUserProfileName) -> Bool {
        return name.first.isBlank || name.last.isBlank
    }

    private func addressIsEmpty(_ address: DBPUIUserProfileAddress) -> Bool {
        return address.city.isBlank || address.state.isBlank
    }

    func getUserProfile() -> DBPUIUserProfile? {
        let profile = profile ?? emptyProfile

        let names = profile.names.map { DBPUIUserProfileName(first: $0.firstName, middle: $0.middleName, last: $0.lastName, suffix: $0.suffix) }
        let addresses = profile.addresses.map { DBPUIUserProfileAddress(street: $0.street, city: $0.city, state: $0.state, zipCode: $0.zipCode) }

        return DBPUIUserProfile(names: names, birthYear: profile.birthYear, addresses: addresses)
    }

    func deleteProfileData() {
        profile = emptyProfile
        delegate?.removeAllData()
    }

    func addNameToCurrentUserProfile(_ name: DBPUIUserProfileName) -> Bool {
        let profile = profile ?? emptyProfile

        guard !isNameEmpty(name) else { return false }

        // No duplicates
        guard indexForName(matching: name, in: profile) == nil else { return false }

        var names = profile.names
        names.append(DataBrokerProtectionProfile.Name(firstName: name.first, lastName: name.last, middleName: name.middle, suffix: name.suffix))

        self.profile = DataBrokerProtectionProfile(names: names, addresses: profile.addresses, phones: profile.phones, birthYear: profile.birthYear)

        return true
    }

    func setNameAtIndexInCurrentUserProfile(_ payload: DBPUINameAtIndex) -> Bool {
        let profile = profile ?? emptyProfile

        var names = profile.names
        if payload.index < names.count {
            names[payload.index] = DataBrokerProtectionProfile.Name(firstName: payload.name.first, lastName: payload.name.last, middleName: payload.name.middle, suffix: payload.name.suffix)
            self.profile = DataBrokerProtectionProfile(names: names, addresses: profile.addresses, phones: profile.phones, birthYear: profile.birthYear)
            return true
        }

        return false
    }

    func removeNameAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool {
        let profile = profile ?? emptyProfile

        var names = profile.names
        if index.index < names.count {
            names.remove(at: index.index)
            self.profile = DataBrokerProtectionProfile(names: names, addresses: profile.addresses, phones: profile.phones, birthYear: profile.birthYear)
            return true
        }

        return false
    }

    func setBirthYearForCurrentUserProfile(_ year: DBPUIBirthYear) -> Bool {
        let profile = profile ?? emptyProfile

        self.profile = DataBrokerProtectionProfile(names: profile.names, addresses: profile.addresses, phones: profile.phones, birthYear: year.year)

        return true
    }

    func addAddressToCurrentUserProfile(_ address: DBPUIUserProfileAddress) -> Bool {
        let profile = profile ?? emptyProfile

        guard !addressIsEmpty(address) else { return false }

        // No duplicates
        guard indexForAddress(matching: address, in: profile) == nil else { return false }

        var addresses = profile.addresses
        addresses.append(DataBrokerProtectionProfile.Address(city: address.city, state: address.state, street: address.street, zipCode: address.zipCode))

        self.profile = DataBrokerProtectionProfile(names: profile.names, addresses: addresses, phones: profile.phones, birthYear: profile.birthYear)

        return true
    }

    func setAddressAtIndexInCurrentUserProfile(_ payload: DBPUIAddressAtIndex) -> Bool {
        let profile = profile ?? emptyProfile

        var addresses = profile.addresses
        if payload.index < addresses.count {
            addresses[payload.index] = DataBrokerProtectionProfile.Address(city: payload.address.city, state: payload.address.state,
                                                                           street: payload.address.street, zipCode: payload.address.zipCode)
            self.profile = DataBrokerProtectionProfile(names: profile.names, addresses: addresses, phones: profile.phones, birthYear: profile.birthYear)
            return true
        }

        return false
    }

    func removeAddressAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool {
        let profile = profile ?? emptyProfile

        var addresses = profile.addresses
        if index.index < addresses.count {
            addresses.remove(at: index.index)
            self.profile = DataBrokerProtectionProfile(names: profile.names, addresses: addresses, phones: profile.phones, birthYear: profile.birthYear)
            return true
        }

        return false
    }

    func startScanAndOptOut() -> Bool {
        return scanDelegate?.startScan() ?? false
    }

    func getInitialScanState() async -> DBPUIInitialScanState {
        await scanDelegate?.updateCacheWithCurrentScans()

        return mapper.initialScanState(brokerProfileQueryData)
    }

    func getMaintananceScanState() async -> DBPUIScanAndOptOutMaintenanceState {
        await scanDelegate?.updateCacheWithCurrentScans()

        return mapper.maintenanceScanState(brokerProfileQueryData)
    }

    func getDataBrokers() async -> [DBPUIDataBroker] {
        brokerProfileQueryData
        // 1. We get all brokers (in this list brokers are repeated)
            .map { $0.dataBroker }
        // 2. We map the brokers to the UI model
            .flatMap { dataBroker -> [DBPUIDataBroker] in
                var result: [DBPUIDataBroker] = []
                result.append(DBPUIDataBroker(name: dataBroker.name, url: dataBroker.url))

                for mirrorSite in dataBroker.mirrorSites {
                    result.append(DBPUIDataBroker(name: mirrorSite.name, url: mirrorSite.url))
                }
                return result
            }
        // 3. We delete duplicates
            .reduce(into: [DBPUIDataBroker]()) { (result, dataBroker) in
                if !result.contains(where: { $0.url == dataBroker.url }) {
                    result.append(dataBroker)
                }
            }
    }
}
