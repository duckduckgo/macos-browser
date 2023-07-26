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

struct ExtractProfileSelectors: Codable, Sendable {
    let name: String?
    let alternativeNamesList: String?
    let addressFull: String?
    let addressCityState: String?
    let addressCityStateList: String?
    let phone: String?
    let phoneList: String?
    let relativesList: String?
    let profileUrl: String?
    let reportId: String?
    let age: String?

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

    init(name: String? = nil,
         alternativeNamesList: String? = nil,
         addressFull: String? = nil,
         addressCityState: String? = nil,
         addressCityStateList: String? = nil,
         phone: String? = nil,
         phoneList: String? = nil,
         relativesList: String? = nil,
         profileUrl: String? = nil,
         reportId: String? = nil,
         age: String? = nil) {
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
    }
}

struct ExtractedProfile: Codable, Sendable {
    let id: UUID = UUID()
    let name: String?
    let alternativeNamesList: [String]?
    let addressFull: String?
    let addressCityState: String?
    let addressCityStateList: [String]?
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

    init(name: String? = nil,
         alternativeNamesList: [String]? = nil,
         addressFull: String? = nil,
         addressCityState: String? = nil,
         addressCityStateList: [String]? = nil,
         phone: String? = nil,
         phoneList: String? = nil,
         relativesList: [String]? = nil,
         profileUrl: String? = nil,
         reportId: String? = nil,
         age: String? = nil,
         email: String? = nil,
         removedDate: Date? = nil) {
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
