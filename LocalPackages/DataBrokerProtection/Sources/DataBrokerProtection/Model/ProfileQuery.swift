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

public struct ProfileQuery: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let city: String
    let state: String
    let age: Int
    let fullName: String
    let profileUrl: String?
    let email: String?

    public init(firstName: String,
                lastName: String,
                city: String,
                state: String,
                age: Int,
                profileUrl: String? = nil,
                email: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.state = state
        self.age = age
        self.fullName = "\(firstName) \(lastName)"
        self.profileUrl = profileUrl
        self.email = email
    }

    public func copy(firstName: String? = nil,
                lastName: String? = nil,
                city: String? = nil,
                state: String? = nil,
                age: Int? = nil,
                profileUrl: String? = nil,
                email: String? = nil) -> ProfileQuery{
        ProfileQuery(
            firstName: firstName ?? self.firstName,
            lastName: lastName ?? self.lastName,
            city: city ?? self.city,
            state: state ?? self.state,
            age: age ?? self.age,
            profileUrl: profileUrl,
            email: email
        )
    }
}
