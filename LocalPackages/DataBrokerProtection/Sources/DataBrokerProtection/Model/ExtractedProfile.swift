//
//  ExtractedProfile.swift
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

struct ProfileSelector: Codable {
    let selector: String
    let findElements: Bool?
}

struct ExtractProfileSelectors: Codable, Sendable {
    let name: ProfileSelector?
    let alternativeNamesList: ProfileSelector?
    let addressFull: ProfileSelector?
    let addressCityState: ProfileSelector?
    let addressCityStateList: ProfileSelector?
    let phone: ProfileSelector?
    let phoneList: ProfileSelector?
    let relativesList: ProfileSelector?
    let profileUrl: ProfileSelector?
    let reportId: String?
    let age: ProfileSelector?

    enum CodingKeys: CodingKey {
        case name
        case alternativeNamesList
        case addressFull
        case addressCityState
        case addressCityStateList
        case phone
        case phoneList
        case relativesList
        case profileUrl
        case reportId
        case age
    }
}

struct AddressCityState: Codable {
    let city: String
    let state: String

    var fullAddress: String {
        "\(city), \(state)"
    }
}

struct ExtractedProfile: Codable, Sendable {
    let id: Int64?
    let name: String?
    let alternativeNamesList: [String]?
    let addressFull: String?
    let addressCityState: String?
    let addressCityStateList: [AddressCityState]?
    let phone: String?
    let phoneList: String?
    let relativesList: [String]?
    let profileUrl: String?
    let reportId: String?
    let age: String?
    var email: String?
    var removedDate: Date?
    let fullName: String?

    enum CodingKeys: CodingKey {
        case id
        case name
        case alternativeNamesList
        case addressFull
        case addressCityState
        case addressCityStateList
        case phone
        case phoneList
        case relativesList
        case profileUrl
        case reportId
        case age
        case email
        case removedDate
        case fullName
    }

    init(id: Int64? = nil,
         name: String? = nil,
         alternativeNamesList: [String]? = nil,
         addressFull: String? = nil,
         addressCityState: String? = nil,
         addressCityStateList: [AddressCityState]? = nil,
         phone: String? = nil,
         phoneList: String? = nil,
         relativesList: [String]? = nil,
         profileUrl: String? = nil,
         reportId: String? = nil,
         age: String? = nil,
         email: String? = nil,
         removedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.alternativeNamesList = alternativeNamesList
        self.addressFull = addressFull
        self.addressCityState = addressCityState
        self.addressCityStateList = addressCityStateList
        self.phone = phone
        self.phoneList = phoneList
        self.relativesList = relativesList
        self.profileUrl = profileUrl
        self.reportId = reportId
        self.age = age
        self.email = email
        self.removedDate = removedDate
        self.fullName = name
    }

    func merge(with profile: ProfileQuery) -> ExtractedProfile {
        ExtractedProfile(
            id: self.id,
            name: self.name ?? profile.fullName,
            alternativeNamesList: self.alternativeNamesList,
            addressFull: self.addressFull,
            addressCityState: self.addressCityState,
            addressCityStateList: self.addressCityStateList,
            phone: self.phone,
            relativesList: self.relativesList,
            profileUrl: self.profileUrl,
            reportId: self.reportId,
            age: self.age ?? String(profile.age),
            email: self.email,
            removedDate: self.removedDate
        )
    }
}

extension ExtractedProfile: Equatable {
    static func == (lhs: ExtractedProfile, rhs: ExtractedProfile) -> Bool {
        lhs.name == rhs.name
    }
}
