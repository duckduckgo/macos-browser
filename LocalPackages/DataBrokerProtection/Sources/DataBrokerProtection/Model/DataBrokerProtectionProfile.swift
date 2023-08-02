//
//  DataBrokerProtectionProfile.swift
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

public struct DataBrokerProtectionProfile: Codable {
    public struct Address: Codable {
        public let city: String
        public let state: String

        public init(city: String, state: String) {
            self.city = city
            self.state = state
        }
    }

    public struct Name: Codable {
        public let firstName: String
        public let lastName: String

        public init(firstName: String, lastName: String) {
            self.firstName = firstName
            self.lastName = lastName
        }
    }

    public let names: [Name]
    public let addresses: [Address]
    public let age: Int

    public init(names: [DataBrokerProtectionProfile.Name],
                addresses: [DataBrokerProtectionProfile.Address],
                age: Int) {
        self.names = names
        self.addresses = addresses
        self.age = age
    }

    func mapToDB() -> ProfileDB {
        guard let firstName = names.first?.firstName,
                let lastName = names.first?.lastName,
                let city = addresses.first?.city,
                let state = addresses.first?.state else {
            fatalError("Profile should have these required fields.")
        }

        return ProfileDB(id: nil,
                         firstName: firstName.data(using: .utf8)!,
                         lastName: lastName.data(using: .utf8)!,
                         city: city.data(using: .utf8)!,
                         state: state.data(using: .utf8)!,
                         age: withUnsafeBytes(of: age) { Data($0) }
        )
    }
}

extension ProfileDB {

    func toProfile() -> DataBrokerProtectionProfile {
        let decodedAge = age.withUnsafeBytes { $0.load(as: Int.self) }
        guard let firstName = String(data: firstName, encoding: .utf8),
              let lastName = String(data: lastName, encoding: .utf8),
              let city = String(data: city, encoding: .utf8),
              let state = String(data: state, encoding: .utf8) else {
                  fatalError("Error on encoding parameters.")
              }

        return DataBrokerProtectionProfile(
            names: [DataBrokerProtectionProfile.Name(firstName: firstName, lastName: lastName)],
            addresses: [DataBrokerProtectionProfile.Address(city: city, state: state)],
            age: decodedAge
        )
    }
}

internal extension DataBrokerProtectionProfile {
    var profileQueries: [ProfileQuery] {
        return addresses.flatMap { address in
            names.map { name in
                ProfileQuery(
                    firstName: name.firstName,
                    lastName: name.lastName,
                    city: address.city,
                    state: address.state,
                    age: age)
            }
        }
    }
}
