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
    var id: UUID { get set }
    var brokerProfileQueryID: UUID { get set }
    var preferredRunDate: Date { get set }
    var historyEvents: [HistoryEvent] { get set }
    var lastRunDate: Date? { get set }

    mutating func addHistoryEvent(_ historyEvent: HistoryEvent)
}

extension BrokerOperationData {
    mutating func addHistoryEvent(_ historyEvent: HistoryEvent) {
        self.historyEvents.append(historyEvent)
    }
}

class ScanOperationData: BrokerOperationData {
    internal init(id: UUID = UUID(),
                  brokerProfileQueryID: UUID,
                  preferredRunDate: Date,
                  historyEvents: [HistoryEvent],
                  lastRunDate: Date? = nil) {

        self.id = id
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
    }

    var id: UUID
    var brokerProfileQueryID: UUID
    var preferredRunDate: Date
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?
}

class OptOutOperationData: BrokerOperationData {
    internal init(id: UUID = UUID(),
                  brokerProfileQueryID: UUID,
                  preferredRunDate: Date,
                  historyEvents: [HistoryEvent],
                  lastRunDate: Date? = nil,
                  extractedProfile: ExtractedProfile) {

        self.id = id
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.extractedProfile = extractedProfile
    }
    var id: UUID
    var brokerProfileQueryID: UUID
    var preferredRunDate: Date
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?

    let extractedProfile: ExtractedProfile
}

//TODO: Remove later
extension ScanOperationData {
    static func createTestScenarios() -> [ScanOperationData] {

        let id1 = UUID()
        let id2 = UUID()
        let preferredRunDate = Date()
        let historyEvents: [HistoryEvent] = []


        let scan1 = ScanOperationData(brokerProfileQueryID: id1, preferredRunDate: preferredRunDate, historyEvents: historyEvents, lastRunDate: nil)

        let scan2 = ScanOperationData(brokerProfileQueryID: id2, preferredRunDate: preferredRunDate, historyEvents: historyEvents, lastRunDate: preferredRunDate)

        return [scan1, scan2]
    }
}
