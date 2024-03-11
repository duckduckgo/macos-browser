//
//  OperationRetriesCalculatorUseCase.swift
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

struct OperationRetriesCalculatorUseCase {

    func calculateForScan(database: DataBrokerProtectionRepository, brokerId: Int64, profileQueryId: Int64) -> Int {
        let events = database.fetchScanHistoryEvents(brokerId: brokerId, profileQueryId: profileQueryId)

        return events.filter { $0.type == .scanStarted }.count
    }

    func calculateForOptOut(database: DataBrokerProtectionRepository, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) -> Int {
        let events = database.fetchOptOutHistoryEvents(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)

        return events.filter { $0.type == .optOutStarted }.count
    }
}
