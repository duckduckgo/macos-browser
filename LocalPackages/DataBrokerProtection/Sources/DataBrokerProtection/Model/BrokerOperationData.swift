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

internal protocol BrokerOperationData {
    var id: UUID { get }
    var brokerProfileQueryID: UUID { get }
    var preferredRunDate: Date? { get set }
    var historyEvents: [HistoryEvent] { get set }
    var lastRunDate: Date? { get set }

    func lastEventWithType(type: HistoryEvent.EventType) -> HistoryEvent?
    mutating func addHistoryEvent(_ historyEvent: HistoryEvent)
}

extension BrokerOperationData {
    mutating func addHistoryEvent(_ historyEvent: HistoryEvent) {
        self.historyEvents.append(historyEvent)
    }

    var lastRunDate: Date? {
        historyEvents.last?.date
    }

    mutating func updatePreferredRunDate(_ date: Date) {
        if preferredRunDate == nil || preferredRunDate! > date {
            preferredRunDate = date
        }
    }

    func lastEventWithType(type: HistoryEvent.EventType) -> HistoryEvent? {
        return historyEvents.last(where: { $0.type == type })
    }
}

public final class ScanOperationData: BrokerOperationData {
    let id: UUID
    let brokerProfileQueryID: UUID
    var preferredRunDate: Date?
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?

    internal init(id: UUID = UUID(),
                  brokerProfileQueryID: UUID,
                  preferredRunDate: Date? = nil,
                  historyEvents: [HistoryEvent],
                  lastRunDate: Date? = nil) {

        self.id = id
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
    }

}

public final class OptOutOperationData: BrokerOperationData {
    let id: UUID
    let brokerProfileQueryID: UUID
    var preferredRunDate: Date?
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date? 
    var extractedProfile: ExtractedProfile

    internal init(id: UUID = UUID(),
                  brokerProfileQueryID: UUID,
                  preferredRunDate: Date? = nil,
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
}
