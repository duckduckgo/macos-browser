//
//  File.swift
//  
//
//  Created by Fernando Bunn on 25/05/2023.
//

import Foundation


struct ExtractedProfile {
    let name: String
}

struct DataBroker {
    let name: String
}

struct ProfileQuery {
    let name: String
}

class BrokerProfileQueryData {
    let id: UUID
    var extractedProfiles: [ExtractedProfile]
    let profileQuery: ProfileQuery
    let dataBroker: DataBroker


    internal init(profileQuery: ProfileQuery, dataBroker: DataBroker) {
        self.id = UUID()
        self.profileQuery = profileQuery
        self.dataBroker = dataBroker
        self.extractedProfiles = [ExtractedProfile]()
    }
}

struct HistoryEvent {
    enum EventType {
        case noMatchFound
        case error
        case optOutRequested
        case optOutConfirmed
        case newMatchFound
        case scanFinished
        case scanStarted
        case oldMatchFound
    }

    let id: UUID
    let type: EventType
    let date: Date
}

protocol BrokerOperationData {
    var brokerProfileQueryID: UUID { get set }
    var preferredRunDate: Date { get set }
    var historyEvents: [HistoryEvent] { get set }
    var lastRunDate: Date? { get set }
}

class ScanOperationData: BrokerOperationData {
    internal init(brokerProfileQueryID: UUID, preferredRunDate: Date, historyEvents: [HistoryEvent], lastRunDate: Date? = nil, brokerProfile: BrokerProfileQueryData) {
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.brokerProfile = brokerProfile
    }

    var brokerProfileQueryID: UUID
    var preferredRunDate: Date
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?

    let brokerProfile: BrokerProfileQueryData

}

class OptOutOperationData: BrokerOperationData {
    internal init(brokerProfileQueryID: UUID, preferredRunDate: Date, historyEvents: [HistoryEvent], lastRunDate: Date? = nil, brokerProfile: BrokerProfileQueryData, extractedProfile: ExtractedProfile) {
        self.brokerProfileQueryID = brokerProfileQueryID
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.brokerProfile = brokerProfile
        self.extractedProfile = extractedProfile
    }

    var brokerProfileQueryID: UUID
    var preferredRunDate: Date
    var historyEvents: [HistoryEvent]
    var lastRunDate: Date?

    let brokerProfile: BrokerProfileQueryData
    let extractedProfile: ExtractedProfile


}
