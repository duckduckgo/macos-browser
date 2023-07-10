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
    let firstName: String
    let lastName: String
    let city: String
    let state: String
    let addresses: [Address]
    let age: Int
    let fullName: String

    public init(firstName: String,
                lastName: String,
                city: String,
                state: String,
                age: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.state = state
        self.addresses = [Address(city: city, state: state)]
        self.age = age
        self.fullName = "\(firstName) \(lastName)"
    }
}
