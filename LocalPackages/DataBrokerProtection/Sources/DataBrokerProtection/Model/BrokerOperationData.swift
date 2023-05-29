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
    internal init(brokerProfileQueryID: UUID, preferredRunDate: Date, historyEvents: [HistoryEvent], lastRunDate: Date? = nil) {
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
    }

    var brokerProfileQueryID: UUID
    var preferredRunDate: Date
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?
}

class OptOutOperationData: BrokerOperationData {
    internal init(brokerProfileQueryID: UUID, preferredRunDate: Date, historyEvents: [HistoryEvent], lastRunDate: Date? = nil, brokerProfile: BrokerProfileQueryData, extractedProfile: ExtractedProfile) {
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.extractedProfile = extractedProfile
    }

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

//TODO: Remove later
extension OptOutOperationData {
    static func createTestScenarios() -> [OptOutOperationData] {
        // Create test data
        let id1 = UUID()
        let id2 = UUID()
        let preferredRunDate = Date()
        let historyEvents: [HistoryEvent] = []
        let brokerProfile = BrokerProfileQueryData.createTestScenario()
        let extractedProfile1 = ExtractedProfile(name: "John Doe")
        let extractedProfile2 = ExtractedProfile(name: "Jane Smith")

        let optOut1 = OptOutOperationData(brokerProfileQueryID: id1, preferredRunDate: preferredRunDate, historyEvents: historyEvents, lastRunDate: nil, brokerProfile: brokerProfile, extractedProfile: extractedProfile1)

        let optOut2 = OptOutOperationData(brokerProfileQueryID: id2, preferredRunDate: preferredRunDate, historyEvents: historyEvents, lastRunDate: preferredRunDate, brokerProfile: brokerProfile, extractedProfile: extractedProfile2)

        return [optOut1, optOut2]
    }
}
