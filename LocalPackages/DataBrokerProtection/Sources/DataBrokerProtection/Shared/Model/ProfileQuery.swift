//
//  ProfileQuery.swift
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

struct Address: Encodable, Sendable {
    let city: String
    let state: String
}

struct ProfileQuery: Encodable, Sendable {
    static let currentYear = Calendar.current.component(.year, from: Date())

    let id: Int64?
    let firstName: String
    let lastName: String
    let middleName: String?
    let suffix: String?
    let city: String
    let state: String
    let street: String?
    let zip: String?
    let addresses: [Address]
    let birthYear: Int
    let phone: String?
    let fullName: String
    let age: Int
    let deprecated: Bool

    public init(id: Int64? = nil,
                firstName: String,
                lastName: String,
                middleName: String? = nil,
                suffix: String? = nil,
                city: String,
                state: String,
                street: String? = nil,
                zipCode: String? = nil,
                phone: String? = nil,
                birthYear: Int,
                deprecated: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.state = state
        self.birthYear = birthYear
        self.middleName = middleName
        self.suffix = suffix
        self.street = street
        self.zip = zipCode
        self.phone = phone
        self.addresses = [Address(city: city, state: state)]
        self.fullName = "\(firstName) \(lastName)"
        self.age = Self.currentYear - birthYear
        self.deprecated = deprecated
    }
}

extension ProfileQuery: Equatable {

    // We're intentionally not comparing IDs since we want to verify only the attributes
    // when we're searching for a potential match in the database
    static func == (lhs: ProfileQuery, rhs: ProfileQuery) -> Bool {
        return
            lhs.firstName.lowercased() == rhs.firstName.lowercased() &&
            lhs.lastName.lowercased() == rhs.lastName.lowercased() &&
            lhs.middleName.normalized() == rhs.middleName.normalized() &&
            lhs.suffix?.lowercased() == rhs.suffix?.lowercased() &&
            lhs.city.lowercased() == rhs.city.lowercased() &&
            lhs.state.lowercased() == rhs.state.lowercased() &&
            lhs.street?.lowercased() == rhs.street?.lowercased() &&
            lhs.zip?.lowercased() == rhs.zip?.lowercased() &&
            lhs.birthYear == rhs.birthYear &&
            lhs.phone?.lowercased() == rhs.phone?.lowercased() &&
            lhs.fullName.lowercased() == rhs.fullName.lowercased() &&
            lhs.age == rhs.age &&
            lhs.addresses == rhs.addresses
    }
}

extension Optional where Wrapped == String {

    /// Returns a comparable string optional for profile query optional fields.
    /// - Returns nil if the string is blank
    /// - Returns nil when the value is nil, or the lowercased String if present
    func normalized() -> String? {
        guard let nonNilString = self else {
            return nil
        }

        return nonNilString.isBlank ? nil : nonNilString.lowercased()
    }
}

extension Address: Equatable {
    static func == (lhs: Address, rhs: Address) -> Bool {
        return lhs.city.lowercased() == rhs.city.lowercased() &&
               lhs.state.lowercased() == rhs.state.lowercased()
    }
}

// Returns a copy of the same instance but with the deprecated flag parameter
extension ProfileQuery {
    func with(deprecated: Bool) -> ProfileQuery {
         return ProfileQuery(id: id,
                             firstName: firstName,
                             lastName: lastName,
                             middleName: middleName,
                             suffix: suffix,
                             city: city,
                             state: state,
                             street: street,
                             zipCode: zip,
                             phone: phone,
                             birthYear: birthYear,
                             deprecated: deprecated)
     }

    func with(id: Int64) -> ProfileQuery {
        return ProfileQuery(id: id,
                            firstName: firstName,
                            lastName: lastName,
                            middleName: middleName,
                            suffix: suffix,
                            city: city,
                            state: state,
                            street: street,
                            zipCode: zip,
                            phone: phone,
                            birthYear: birthYear,
                            deprecated: deprecated)
    }
}

extension ProfileQuery: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(firstName.lowercased())
        hasher.combine(lastName.lowercased())
        hasher.combine(middleName?.lowercased())
        hasher.combine(suffix?.lowercased())
        hasher.combine(city.lowercased())
        hasher.combine(state.lowercased())
        hasher.combine(street?.lowercased())
        hasher.combine(zip?.lowercased())
        hasher.combine(birthYear)
        hasher.combine(phone?.lowercased())
        hasher.combine(fullName.lowercased())
        hasher.combine(age)
        hasher.combine(addresses)
    }
}

extension Address: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(city.lowercased())
        hasher.combine(state.lowercased())
    }
}
