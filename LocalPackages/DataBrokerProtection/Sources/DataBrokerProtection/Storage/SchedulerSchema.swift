//
//  SchedulerSchema.swift
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

struct ProfileQueryDB: Codable {
    let id: Int64?
    let profileId: Int64
    let first: Data
    let last: Data
    let middle: Data?
    let suffix: Data?
    let city: Data
    let state: Data
    let street: Data?
    let zipCode: Data?
    let phone: Data?
    let birthYear: Data
}

extension ProfileQueryDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "profileQuery"

    enum Columns: String, ColumnExpression {
        case id
        case profileId
        case first
        case last
        case middle
        case suffix
        case city
        case state
        case street
        case zipCode
        case phone
        case birthYear
    }

    init(row: Row) throws {
        id = row[Columns.id]
        profileId = row[Columns.profileId]
        first = row[Columns.first]
        last = row[Columns.last]
        middle = row[Columns.middle]
        suffix = row[Columns.suffix]
        city = row[Columns.city]
        state = row[Columns.state]
        street = row[Columns.street]
        zipCode = row[Columns.zipCode]
        phone = row[Columns.phone]
        birthYear = row[Columns.birthYear]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.profileId] = profileId
        container[Columns.first] = first
        container[Columns.last] = last
        container[Columns.middle] = middle
        container[Columns.suffix] = suffix
        container[Columns.city] = city
        container[Columns.state] = state
        container[Columns.street] = street
        container[Columns.zipCode] = zipCode
        container[Columns.phone] = phone
        container[Columns.birthYear] = birthYear
    }
}

struct BrokerDB: Codable {
    let id: Int64?
    let name: String
    let json: Data
    let version: String
}

extension BrokerDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "broker"

    enum Columns: String, ColumnExpression {
        case id
        case name
        case json
        case version
    }

    init(row: Row) throws {
        id = row[Columns.id]
        name = row[Columns.name]
        json = row[Columns.json]
        version = row[Columns.version]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.json] = json
        container[Columns.version] = version
    }
}

struct ScanDB: Codable {
    let brokerId: Int64
    let profileQueryId: Int64
    var lastRunDate: Date?
    var preferredRunDate: Date?
}

extension ScanDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "scan"

    static let profileQuery = belongsTo(ProfileQueryDB.self)
    static let broker = belongsTo(BrokerDB.self)

    enum Columns: String, ColumnExpression {
        case brokerId
        case profileQueryId
        case lastRunDate
        case preferredRunDate
    }

    init(row: Row) throws {
        brokerId = row[Columns.brokerId]
        profileQueryId = row[Columns.profileQueryId]
        lastRunDate = row[Columns.lastRunDate]
        preferredRunDate = row[Columns.preferredRunDate]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.brokerId] = brokerId
        container[Columns.profileQueryId] = profileQueryId
        container[Columns.lastRunDate] = lastRunDate
        container[Columns.preferredRunDate] = preferredRunDate
    }
}

struct ScanHistoryEventDB: Codable {
    let brokerId: Int64
    let profileQueryId: Int64
    let event: Data
    let timestamp: Date
}

extension ScanHistoryEventDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "scanHistoryEvent"

    static let profileQuery = belongsTo(ProfileQueryDB.self)
    static let broker = belongsTo(BrokerDB.self)

    enum Columns: String, ColumnExpression {
        case brokerId
        case profileQueryId
        case event
        case timestamp
    }

    init(row: Row) throws {
        brokerId = row[Columns.brokerId]
        profileQueryId = row[Columns.profileQueryId]
        event = row[Columns.event]
        timestamp = row[Columns.timestamp]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.brokerId] = brokerId
        container[Columns.profileQueryId] = profileQueryId
        container[Columns.event] = event
        container[Columns.timestamp] = timestamp
    }
}

struct OptOutDB: Codable {
    let brokerId: Int64
    let profileQueryId: Int64
    let extractedProfileId: Int64
    var lastRunDate: Date?
    var preferredRunDate: Date?
}

extension OptOutDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "optOut"

    static let profileQuery = belongsTo(ProfileQueryDB.self)
    static let broker = belongsTo(BrokerDB.self)
    static let extractedProfile = belongsTo(ExtractedProfileDB.self)

    var extractedProfile: QueryInterfaceRequest<ExtractedProfileDB> {
        request(for: OptOutDB.extractedProfile)
    }

    enum Columns: String, ColumnExpression {
        case brokerId
        case profileQueryId
        case extractedProfileId
        case lastRunDate
        case preferredRunDate
    }

    init(row: Row) throws {
        brokerId = row[Columns.brokerId]
        profileQueryId = row[Columns.profileQueryId]
        extractedProfileId = row[Columns.extractedProfileId]
        lastRunDate = row[Columns.lastRunDate]
        preferredRunDate = row[Columns.preferredRunDate]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.brokerId] = brokerId
        container[Columns.profileQueryId] = profileQueryId
        container[Columns.extractedProfileId] = extractedProfileId
        container[Columns.lastRunDate] = lastRunDate
        container[Columns.preferredRunDate] = preferredRunDate
    }
}

struct OptOutHistoryEventDB: Codable {
    let brokerId: Int64
    let profileQueryId: Int64
    let extractedProfileId: Int64
    let event: Data
    let timestamp: Date
}

extension OptOutHistoryEventDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "optOutHistoryEvent"

    static let profileQuery = belongsTo(ProfileQueryDB.self)
    static let broker = belongsTo(BrokerDB.self)
    static let extractedProfile = belongsTo(ExtractedProfileDB.self)

    enum Columns: String, ColumnExpression {
        case brokerId
        case profileQueryId
        case extractedProfileId
        case event
        case timestamp
    }

    init(row: Row) throws {
        brokerId = row[Columns.brokerId]
        profileQueryId = row[Columns.profileQueryId]
        extractedProfileId = row[Columns.extractedProfileId]
        event = row[Columns.event]
        timestamp = row[Columns.timestamp]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.brokerId] = brokerId
        container[Columns.profileQueryId] = profileQueryId
        container[Columns.extractedProfileId] = extractedProfileId
        container[Columns.event] = event
        container[Columns.timestamp] = timestamp
    }
}

struct ExtractedProfileDB: Codable {
    let id: Int64?
    let brokerId: Int64
    let profileQueryId: Int64
    let profile: Data // Stored as Data JSON
    var removedDate: Date?
}

extension ExtractedProfileDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "extractedProfile"

    static let profileQuery = belongsTo(ProfileQueryDB.self)
    static let broker = belongsTo(BrokerDB.self)

    enum Columns: String, ColumnExpression {
        case id
        case brokerId
        case profileQueryId
        case profile
        case removedDate
    }

    init(row: Row) throws {
        id = row[Columns.id]
        brokerId = row[Columns.brokerId]
        profileQueryId = row[Columns.profileQueryId]
        profile = row[Columns.profile]
        removedDate = row[Columns.removedDate]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.brokerId] = brokerId
        container[Columns.profileQueryId] = profileQueryId
        container[Columns.profile] = profile
        container[Columns.removedDate] = removedDate
    }
}

struct OptOutAttemptDB: Codable {
    let extractedProfileId: Int64
    let dataBroker: String
    var attemptId: String
    var lastStageDate: Date
    var startDate: Date
}

extension OptOutAttemptDB: PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "optOutAttempt"

    static let extractedProfile = belongsTo(ExtractedProfileDB.self)

    enum Columns: String, ColumnExpression {
        case extractedProfileId
        case dataBroker
        case attemptId
        case lastStageDate
        case startDate
    }

    init(row: Row) throws {
        extractedProfileId = row[Columns.extractedProfileId]
        dataBroker = row[Columns.dataBroker]
        attemptId = row[Columns.attemptId]
        lastStageDate = row[Columns.lastStageDate]
        startDate = row[Columns.startDate]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.extractedProfileId] = extractedProfileId
        container[Columns.dataBroker] = dataBroker
        container[Columns.attemptId] = attemptId
        container[Columns.lastStageDate] = lastStageDate
        container[Columns.startDate] = startDate
    }
}
