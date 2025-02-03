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
    public struct Name: Codable {
        public let firstName: String
        public let lastName: String
        public let middleName: String?
        public let suffix: String?

        public init(firstName: String,
                    lastName: String,
                    middleName: String? = nil,
                    suffix: String? = nil) {
            self.firstName = firstName
            self.lastName = lastName
            self.middleName = middleName
            self.suffix = suffix
        }
    }

    public struct Address: Codable {
        public let city: String
        public let state: String
        public let street: String?
        public let zipCode: String?

        public init(city: String,
                    state: String,
                    street: String? = nil,
                    zipCode: String? = nil) {
            self.city = city
            self.state = state
            self.street = street
            self.zipCode = zipCode
        }
    }

    public let names: [Name]
    public let addresses: [Address]
    public let phones: [String]
    public let birthYear: Int

    public init(names: [DataBrokerProtectionProfile.Name],
                addresses: [DataBrokerProtectionProfile.Address],
                phones: [String],
                birthYear: Int) {
        self.names = names
        self.addresses = addresses
        self.phones = phones
        self.birthYear = birthYear
    }
}

extension DataBrokerProtectionProfile {
    var profileQueries: [ProfileQuery] {
        return addresses.flatMap { address in
            names.map { name in
                ProfileQuery(
                    firstName: name.firstName,
                    lastName: name.lastName,
                    middleName: name.middleName,
                    city: address.city,
                    state: address.state,
                    birthYear: birthYear,
                    deprecated: false)
            }
        }
    }
}
