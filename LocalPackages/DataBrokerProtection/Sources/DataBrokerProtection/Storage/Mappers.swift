//
//  Mappers.swift
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

struct MapperToDB {

    private let mechanism: (Data) throws -> Data

    init(mechanism: @escaping (Data) throws -> Data) {
        self.mechanism = mechanism
    }

    func mapToDB(profile: DataBrokerProtectionProfile) throws -> ProfileDB {
        .init(id: nil, age: try withUnsafeBytes(of: profile.age) { try mechanism(Data($0)) })
    }

    func mapToDB(_ name: DataBrokerProtectionProfile.Name, relatedTo profileId: Int64) throws -> NameDB {
        .init(
            first: try mechanism(name.firstName.encoded),
            last: try mechanism(name.lastName.encoded),
            profileId: profileId,
            middle: try name.middleName.encoded(mechanism),
            suffix: try name.suffix.encoded(mechanism)
        )
    }

    func mapToDB(_ address: DataBrokerProtectionProfile.Address, relatedTo profileId: Int64) throws -> AddressDB {
        .init(
            city: try mechanism(address.city.encoded),
            state: try mechanism(address.state.encoded),
            profileId: profileId,
            street: try address.street.encoded(mechanism),
            zipCode: try address.zipCode.encoded(mechanism)
        )
    }

    func mapToDB(_ phone: String, relatedTo profileId: Int64) throws -> PhoneDB {
        .init(phoneNumber: try mechanism(phone.encoded), profileId: profileId)
    }
}

struct MapperToModel {

    private let mechanism: (Data) throws -> Data

    init(mechanism: @escaping (Data) throws -> Data) {
        self.mechanism = mechanism
    }

    func mapToModel(_ profile: FullProfileDB) throws -> DataBrokerProtectionProfile {
        .init(
            names: try profile.names.map(mapToModel(_:)),
            addresses: try profile.addresses.map(mapToModel(_:)),
            phones: try profile.phones.map(mapToModel(_:)),
            age: try mechanism(profile.profile.age).withUnsafeBytes {
                $0.load(as: Int.self)
            }
        )
    }

    private func mapToModel(_ nameDB: NameDB) throws -> DataBrokerProtectionProfile.Name {
        .init(
            firstName: try mechanism(nameDB.first).decoded,
            lastName: try mechanism(nameDB.last).decoded,
            middleName: try nameDB.middle.decode(mechanism),
            suffix: try nameDB.suffix.decode(mechanism)
        )
    }

    private func mapToModel(_ addressDB: AddressDB) throws -> DataBrokerProtectionProfile.Address {
        .init(
            city: try mechanism(addressDB.city).decoded,
            state: try mechanism(addressDB.state).decoded,
            street: try addressDB.street.decode(mechanism),
            zipCode: try addressDB.zipCode.decode(mechanism)
        )
    }

    private func mapToModel(_ phoneDB: PhoneDB) throws -> String {
        try mechanism(phoneDB.phoneNumber).decoded
    }
}

extension Optional where Wrapped == String {

    func encoded(_ mechanism: (Data) throws -> Data) throws -> Data? {
        guard let value = self else {
            return nil
        }

        return try mechanism(value.encoded)
    }
}

extension String {

    var encoded: Data {
        guard let encodedString = self.data(using: .utf8) else {
            fatalError("Mappers: Failed trying to encode String")
        }

        return encodedString
    }
}

extension Optional where Wrapped == Data {

    func decode(_ mechanism: (Data) throws -> Data) throws -> String? {
        guard let value = self else {
            return nil
        }

        return try mechanism(value).decoded
    }
}

extension Data {

    var decoded: String {
        guard let decodedString = String(data: self, encoding: .utf8) else {
            fatalError("Mappers: Failed trying to decode data")
        }

        return decodedString
    }
}
