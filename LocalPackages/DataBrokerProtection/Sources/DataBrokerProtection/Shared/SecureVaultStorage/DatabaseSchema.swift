//
//  DatabaseSchema.swift
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
import BrowserServicesKit
import SecureStorage
import GRDB

struct ProfileDB: Codable {
    let id: Int64?
    let birthYear: Data
}

struct NameDB: Codable {
    let first: Data
    let last: Data
    let profileId: Int64
    let middle: Data?
    let suffix: Data?
}

struct AddressDB: Codable {
    let city: Data
    let state: Data
    let profileId: Int64
    let street: Data?
    let zipCode: Data?
}

struct PhoneDB: Codable {
    let phoneNumber: Data
    let profileId: Int64
}

struct FullProfileDB: FetchableRecord, Decodable {
    var profile: ProfileDB
    var names: [NameDB]
    var addresses: [AddressDB]
    var phones: [PhoneDB]
}

extension PhoneDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "phone"
    static let profile = belongsTo(ProfileDB.self)

    enum Columns: String, ColumnExpression {
        case phoneNumber
        case profileId
    }

    init(row: Row) throws {
        phoneNumber = row[Columns.phoneNumber]
        profileId = row[Columns.profileId]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.phoneNumber] = phoneNumber
        container[Columns.profileId] = profileId
    }
}

extension AddressDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "address"
    static let profile = belongsTo(ProfileDB.self)

    enum Columns: String, ColumnExpression {
        case city
        case state
        case profileId
        case street
        case zipCode
    }

    init(row: Row) throws {
        city = row[Columns.city]
        state = row[Columns.state]
        profileId = row[Columns.profileId]
        street = row[Columns.street]
        zipCode = row[Columns.zipCode]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.city] = city
        container[Columns.state] = state
        container[Columns.profileId] = profileId
        container[Columns.street] = street
        container[Columns.zipCode] = zipCode
    }
}

extension NameDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "name"
    static let profile = belongsTo(ProfileDB.self)

    enum Columns: String, ColumnExpression {
        case first
        case last
        case profileId
        case middle
        case suffix
    }

    init(row: Row) throws {
        first = row[Columns.first]
        last = row[Columns.last]
        profileId = row[Columns.profileId]
        middle = row[Columns.middle]
        suffix = row[Columns.suffix]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.first] = first
        container[Columns.last] = last
        container[Columns.profileId] = profileId
        container[Columns.middle] = middle
        container[Columns.suffix] = suffix
    }
}

extension ProfileDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "profile"
    static let names = hasMany(NameDB.self)
    static let addresses = hasMany(AddressDB.self)
    static let phoneNumbers = hasMany(PhoneDB.self)

    enum Columns: String, ColumnExpression {
        case id
        case birthYear
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        birthYear = row[Columns.birthYear]
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.birthYear] = birthYear
    }
}
