//
//  BrokerOperationData.swift
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

protocol BrokerOperationData {
    var brokerId: Int64 { get }
    var profileQueryId: Int64 { get }
    var lastRunDate: Date? { get }
    var preferredRunDate: Date? { get }
    var historyEvents: [HistoryEvent] { get }
}

struct ScanOperationData: BrokerOperationData, Sendable {
    let brokerId: Int64
    let profileQueryId: Int64
    let preferredRunDate: Date?
    let historyEvents: [HistoryEvent]
    let lastRunDate: Date?

    init(brokerId: Int64,
         profileQueryId: Int64,
         preferredRunDate: Date? = nil,
         historyEvents: [HistoryEvent],
         lastRunDate: Date? = nil) {
        self.brokerId = brokerId
        self.profileQueryId = profileQueryId
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
    }

}

struct OptOutOperationData: BrokerOperationData, Sendable {
    let brokerId: Int64
    let profileQueryId: Int64
    let preferredRunDate: Date?
    let historyEvents: [HistoryEvent]
    let lastRunDate: Date?
    let extractedProfile: ExtractedProfile

    init(brokerId: Int64,
         profileQueryId: Int64,
         preferredRunDate: Date? = nil,
         historyEvents: [HistoryEvent],
         lastRunDate: Date? = nil,
         extractedProfile: ExtractedProfile) {
        self.brokerId = brokerId
        self.profileQueryId = profileQueryId
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.extractedProfile = extractedProfile
    }
}
