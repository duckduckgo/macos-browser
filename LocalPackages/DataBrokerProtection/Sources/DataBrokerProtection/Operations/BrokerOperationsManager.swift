//
//  BrokerOperationsManager.swift
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

protocol OperationsManager {
    init(brokerProfileQueryData: BrokerProfileQueryData, database: DataBase)

    func saveExtractedProfiles(_ profiles: [ExtractedProfile])
}

/*
 This will run the operations
 Handle its data updates
 Expose its data for the Scheduler
 BrokerProfileQueryData being the main model
 */
class BrokerOperationsManager: OperationsManager {
    let brokerProfileQueryData: BrokerProfileQueryData
    let database: DataBase

    required init(brokerProfileQueryData: BrokerProfileQueryData, database: DataBase) {
        self.brokerProfileQueryData = brokerProfileQueryData
        self.database = database
    }

    func runScanOperation(on runner: OperationRunner) async throws {
        let profiles = try await runner.scan(brokerProfileQueryData)
    }

    func runOptOutOperation(for extractedProfile: ExtractedProfile, on runner: OperationRunner) async throws {
        try await runner.optOut(extractedProfile)
    }

    func saveExtractedProfiles(_ profiles: [ExtractedProfile]) {
        //TODO: Compare old and new profiles, set dateCreated on tem
        fatalError("no op")
    }

}
