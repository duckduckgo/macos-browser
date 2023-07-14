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
