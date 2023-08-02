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

struct ProfileDB {
    let id: Int64?
    let firstName: Data
    let lastName: Data
    let city: Data
    let state: Data
    let age: Data
}

extension ProfileDB: PersistableRecord, FetchableRecord {
    public static var databaseTableName: String = "dbp_profiles"

    enum Columns: String, ColumnExpression {
        case id
        case firstName
        case lastName
        case city
        case state
        case age
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        firstName = row[Columns.firstName]
        lastName = row[Columns.lastName]
        city = row[Columns.city]
        state = row[Columns.state]
        age = row[Columns.age]
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.firstName] = firstName
        container[Columns.lastName] = lastName
        container[Columns.city] = city
        container[Columns.state] = state
        container[Columns.age] = age
    }

    func encrypt(_ mechanism: (Data) throws -> Data) throws -> ProfileDB {
        .init(
            id: id,
            firstName: try mechanism(firstName),
            lastName: try mechanism(lastName),
            city: try mechanism(city),
            state: try mechanism(state),
            age: try mechanism(age)
        )
    }

    func decrypt(_ mechanism: (Data) throws -> Data) throws -> ProfileDB {
        .init(
            id: id,
            firstName: try mechanism(firstName),
            lastName: try mechanism(lastName),
            city: try mechanism(city),
            state: try mechanism(state),
            age: try mechanism(age)
        )
    }
}
