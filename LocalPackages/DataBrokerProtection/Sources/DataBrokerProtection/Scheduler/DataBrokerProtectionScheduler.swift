//
//  DataBrokerProtectionScheduler.swift
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

class DataBrokerProtectionScheduler {
    var operationManagers: [OperationsManager]
    let database: DataBase

    init(database: DataBase) {
        self.database = database
        self.operationManagers = [OperationsManager]()

        setupManagers()
    }

    private func setupManagers() {
        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        operationManagers = brokersProfileData.map {
            BrokerOperationsManager(profileQuery: $0.profileQuery, dataBroker: $0.dataBroker, database: database)
        }
    }
}
