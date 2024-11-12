//
//  DBPUICommunicationModel.swift
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

enum DBPUIError: Error {
    case malformedRequest
}

extension DBPUIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedRequest:
            return "MALFORMED_REQUEST"
        }
    }
}

/// Enum to represent the requested UI State
enum DBPUIState: String, Codable {
    case onboarding = "Onboarding"
    case profileReview = "ProfileReview"
    case dashboard = "Dashboard"
}

/// Handshake request from the UI
struct DBPUIHandshake: Codable {
    let version: Int
}

/// User-related data intended to be returned as part of a hardshake response
struct DBPUIHandshakeUserData: Codable, Equatable {
    let isAuthenticatedUser: Bool
}

/// Data type returned in response to a handshake request
struct DBPUIHandshakeResponse: Codable {
    let version: Int
    let success: Bool
    let userdata: DBPUIHandshakeUserData
}

/// Standard response from the host to the UI. The response contains the
/// current version of the host's communication protocol and a bool value
/// indicating if the requested operation was successful.
struct DBPUIStandardResponse: Codable {
    let version: Int
    let success: Bool
    let id: String?
    let message: String?

    init(version: Int, success: Bool, id: String? = nil, message: String? = nil) {
        self.version = version
        self.success = success
        self.id = id
        self.message = message
    }
}

/// Message Object representing a user profile name
struct DBPUIUserProfileName: Codable {
    let first: String
    let middle: String?
    let last: String
    let suffix: String?
}

/// Message Object representing a user profile address
struct DBPUIUserProfileAddress: Codable {
    let street: String?
    let city: String
    let state: String
    let zipCode: String?
}

extension DBPUIUserProfileAddress {
    init(addressCityState: AddressCityState) {
        self.init(street: addressCityState.fullAddress,
                  city: addressCityState.city,
                  state: addressCityState.state,
                  zipCode: nil)
    }
}

/// Message Object representing a user profile containing one or more names and addresses
/// also contains the user profile's birth year
struct DBPUIUserProfile: Codable {
    let names: [DBPUIUserProfileName]
    let birthYear: Int
    let addresses: [DBPUIUserProfileAddress]
}

/// Message Object representing an index. This is used to determine a particular name or
/// address that should be removed from a user profile
struct DBPUIIndex: Codable {
    let index: Int
}

struct DBPUINameAtIndex: Codable {
    let index: Int
    let name: DBPUIUserProfileName
}

struct DBPUIAddressAtIndex: Codable {
    let index: Int
    let address: DBPUIUserProfileAddress
}

/// Message Object representing a data broker
struct DBPUIDataBroker: Codable, Hashable {
    let name: String
    let url: String
    let date: Double?
    let parentURL: String?
    let optOutUrl: String

    init(name: String, url: String, date: Double? = nil, parentURL: String?, optOutUrl: String) {
        self.name = name
        self.url = url
        self.date = date
        self.parentURL = parentURL
        self.optOutUrl = optOutUrl
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct DBPUIDataBrokerList: DBPUISendableMessage {
    let dataBrokers: [DBPUIDataBroker]
}

/// Message Object representing a requested change to the user profile's birth year
struct DBPUIBirthYear: Codable {
    let year: Int
}

/// Message Object representing a supported timeline event
/// https://app.asana.com/0/481882893211075/1208663928051302/f
struct DBPUITimelineEvent: Codable {
    enum EventType: String, Codable {
        case recordFound = "record-found"
        case recordReappeared = "record-reappeared"
        case optOutSubmitted = "opt-out-submitted"
        case estimatedRemoval = "estimated-removal"
        case removed = "removed"
    }

    let type: EventType
    let date: Double

    var eventDate: Date {
        Date(timeIntervalSince1970: date)
    }

    init?(type: EventType, date: Date?) {
        guard let date else { return nil }
        self.type = type
        self.date = date.timeIntervalSince1970
    }
}

extension DBPUITimelineEvent {
    init?(foundDate: Date?) {
        self.init(type: .recordFound, date: foundDate)
    }

    init?(reappearedDate: Date?) {
        self.init(type: .recordReappeared, date: reappearedDate)
    }

    init?(optOutSubmittedDate: Date?) {
        self.init(type: .optOutSubmitted, date: optOutSubmittedDate)
    }

    init?(estimatedRemovalDate: Date?) {
        self.init(type: .estimatedRemoval, date: estimatedRemovalDate)
    }

    init?(removedDate: Date?) {
        self.init(type: .removed, date: removedDate)
    }

    static func from(historyEvents: [HistoryEvent], removedDate: Date?) -> [DBPUITimelineEvent] {
        var timelineEvents = historyEvents.compactMap { event in
            switch event.type {
            case .matchesFound:
                return DBPUITimelineEvent(foundDate: event.date)
            case .reAppearence:
                return DBPUITimelineEvent(reappearedDate: event.date)
            case .optOutRequested:
                return DBPUITimelineEvent(optOutSubmittedDate: event.date)
            default:
                return nil
            }
        }

        let mostRecentFoundEvent = timelineEvents.filter({ $0.type == .recordFound || $0.type == .recordReappeared }).max(by: <)
        let mostRecentOptOutSubmittedEvent = timelineEvents.filter({ $0.type == .optOutSubmitted }).max(by: <)

        if let optOutSubmittedDate = (mostRecentOptOutSubmittedEvent ?? mostRecentFoundEvent)?.eventDate,
           let estimatedRemovalEvent = DBPUITimelineEvent(estimatedRemovalDate: Calendar.current.date(byAdding: .day, value: 14, to: optOutSubmittedDate)) {
            timelineEvents.append(estimatedRemovalEvent)
        }

        if let removedEvent = DBPUITimelineEvent(removedDate: removedDate) {
            timelineEvents.append(removedEvent)
        }

        return timelineEvents
    }
}

extension DBPUITimelineEvent: Comparable {
    static func < (lhs: DBPUITimelineEvent, rhs: DBPUITimelineEvent) -> Bool {
        lhs.date < rhs.date
    }
}

/// Message object containing information related to a profile match on a data broker
/// The message contains the data broker on which the profile was found and the names
/// and addresses that were matched
struct DBPUIDataBrokerProfileMatch: Codable {
    let dataBroker: DBPUIDataBroker
    let name: String
    let addresses: [DBPUIUserProfileAddress]
    let alternativeNames: [String]
    let relatives: [String]
    let timelineEvents: [DBPUITimelineEvent]
    let hasMatchingRecordOnParentBroker: Bool

    init(dataBroker: DBPUIDataBroker,
         name: String,
         addresses: [DBPUIUserProfileAddress],
         alternativeNames: [String],
         relatives: [String],
         timelineEvents: [DBPUITimelineEvent],
         hasMatchingRecordOnParentBroker: Bool) {
        self.dataBroker = dataBroker
        self.name = name
        self.addresses = addresses
        self.alternativeNames = alternativeNames
        self.relatives = relatives
        self.timelineEvents = timelineEvents.sorted(by: <)
        self.hasMatchingRecordOnParentBroker = hasMatchingRecordOnParentBroker
    }
}

extension DBPUIDataBrokerProfileMatch {
    init(optOutJobData: OptOutJobData,
         dataBrokerName: String,
         dataBrokerURL: String,
         dataBrokerParentURL: String?,
         parentBrokerOptOutJobData: [OptOutJobData]?,
         optOutUrl: String) {
        let extractedProfile = optOutJobData.extractedProfile
        let timelineEvents = DBPUITimelineEvent.from(historyEvents: optOutJobData.historyEvents, removedDate: extractedProfile.removedDate)

        // Check for any matching records on the parent broker
        let hasFoundParentMatch = parentBrokerOptOutJobData?.contains { parentOptOut in
            extractedProfile.doesMatchExtractedProfile(parentOptOut.extractedProfile)
        } ?? false

        self.init(dataBroker: DBPUIDataBroker(name: dataBrokerName, url: dataBrokerURL, parentURL: dataBrokerParentURL, optOutUrl: optOutUrl),
                  name: extractedProfile.fullName ?? "No name",
                  addresses: extractedProfile.addresses?.map {DBPUIUserProfileAddress(addressCityState: $0) } ?? [],
                  alternativeNames: extractedProfile.alternativeNames ?? [String](),
                  relatives: extractedProfile.relatives ?? [String](),
                  timelineEvents: timelineEvents,
                  hasMatchingRecordOnParentBroker: hasFoundParentMatch)
    }

    init(optOutJobData: OptOutJobData, dataBroker: DataBroker, parentBrokerOptOutJobData: [OptOutJobData]?, optOutUrl: String) {
        self.init(optOutJobData: optOutJobData,
                  dataBrokerName: dataBroker.name,
                  dataBrokerURL: dataBroker.url,
                  dataBrokerParentURL: dataBroker.parent,
                  parentBrokerOptOutJobData: parentBrokerOptOutJobData,
                  optOutUrl: optOutUrl)
    }

    /// Generates an array of `DBPUIDataBrokerProfileMatch` objects from the provided query data.
    ///
    /// This method processes an array of `BrokerProfileQueryData` to create a list of profile matches for data brokers.
    /// It takes into account the opt-out data associated with each data broker, as well as any parent data brokers and their opt-out data.
    /// Additionally, it includes mirror sites for each data broker, if applicable, based on the conditions defined in `shouldWeIncludeMirrorSite()`.
    ///
    /// - Parameter queryData: An array of `BrokerProfileQueryData` objects, which contains data brokers and their respective opt-out data.
    /// - Returns: An array of `DBPUIDataBrokerProfileMatch` objects representing matches for each data broker, including parent brokers and mirror sites.
    static func profileMatches(from queryData: [BrokerProfileQueryData]) -> [DBPUIDataBrokerProfileMatch] {
        // Group the query data by data broker URL to easily find parent data broker opt-outs later.
        let brokerURLsToQueryData = Dictionary(grouping: queryData, by: { $0.dataBroker.url })

        return queryData.flatMap {
            var profiles = [DBPUIDataBrokerProfileMatch]()

            for optOutJobData in $0.optOutJobData {
                let dataBroker = $0.dataBroker

                // Find opt-out job data for the parent broker, if applicable.
                var parentBrokerOptOutJobData: [OptOutJobData]?
                if let parent = dataBroker.parent,
                   let parentsQueryData = brokerURLsToQueryData[parent] {
                    parentBrokerOptOutJobData = parentsQueryData.flatMap { $0.optOutJobData }
                }

                // Create a profile match for the current data broker and append it to the list of profiles.
                profiles.append(DBPUIDataBrokerProfileMatch(optOutJobData: optOutJobData,
                                                            dataBroker: dataBroker,
                                                            parentBrokerOptOutJobData: parentBrokerOptOutJobData,
                                                            optOutUrl: dataBroker.optOutUrl))

                // Handle mirror sites associated with the data broker.
                if !dataBroker.mirrorSites.isEmpty {
                    // Create profile matches for each mirror site if it meets the inclusion criteria.
                    let mirrorSitesMatches = dataBroker.mirrorSites.compactMap { mirrorSite in
                        if mirrorSite.shouldWeIncludeMirrorSite() {
                            return DBPUIDataBrokerProfileMatch(optOutJobData: optOutJobData,
                                                               dataBrokerName: mirrorSite.name,
                                                               dataBrokerURL: mirrorSite.url,
                                                               dataBrokerParentURL: dataBroker.parent,
                                                               parentBrokerOptOutJobData: parentBrokerOptOutJobData,
                                                               optOutUrl: dataBroker.optOutUrl)
                        }
                        return nil
                    }
                    profiles.append(contentsOf: mirrorSitesMatches)
                }
            }

            return profiles
        }
    }
}

/// Protocol to represent a message that can be passed from the host to the UI
protocol DBPUISendableMessage: Codable {}

/// Message representing the state of any scans and opt outs without state and grouping removed profiles by broker
struct DBPUIScanAndOptOutMaintenanceState: DBPUISendableMessage {
    let inProgressOptOuts: [DBPUIDataBrokerProfileMatch]
    let completedOptOuts: [DBPUIOptOutMatch]
    let scanSchedule: DBPUIScanSchedule
    let scanHistory: DBPUIScanHistory
}

struct DBPUIOptOutMatch: DBPUISendableMessage {
    let dataBroker: DBPUIDataBroker
    let matches: Int
    let name: String
    let alternativeNames: [String]
    let addresses: [DBPUIUserProfileAddress]
    let date: Double
    let timelineEvents: [DBPUITimelineEvent]
}

extension DBPUIOptOutMatch {
    init?(profileMatch: DBPUIDataBrokerProfileMatch, matches: Int) {
        guard let removedDate = profileMatch.timelineEvents.filter({ $0.type == .removed }).first?.date else { return nil }
        let dataBroker = profileMatch.dataBroker
        self.init(dataBroker: dataBroker,
                  matches: matches,
                  name: profileMatch.name,
                  alternativeNames: profileMatch.alternativeNames,
                  addresses: profileMatch.addresses,
                  date: removedDate,
                  timelineEvents: profileMatch.timelineEvents)
    }
}

/// Data representing the initial scan progress
struct DBPUIScanProgress: DBPUISendableMessage {

    struct ScannedBroker: Codable, Equatable {

        enum Status: String, Codable {
            case inProgress = "in-progress"
            case completed
        }

        let name: String
        let url: String
        let status: Status
    }

    let currentScans: Int
    let totalScans: Int
    let scannedBrokers: [ScannedBroker]
}

/// Data to represent the intial scan state
/// It will show the current scans + total, and the results found
struct DBPUIInitialScanState: DBPUISendableMessage {
    let resultsFound: [DBPUIDataBrokerProfileMatch]
    let scanProgress: DBPUIScanProgress
}

struct DBPUIScanDate: DBPUISendableMessage {
    let date: Double
    let dataBrokers: [DBPUIDataBroker]
}

struct DBPUIScanSchedule: DBPUISendableMessage {
    let lastScan: DBPUIScanDate
    let nextScan: DBPUIScanDate
}

struct DBPUIScanHistory: DBPUISendableMessage {
    let sitesScanned: Int
}

struct DBPUIDebugMetadata: DBPUISendableMessage {
    let lastRunAppVersion: String
    let lastRunAgentVersion: String?
    let isAgentRunning: Bool
    let lastSchedulerOperationType: String? // scan or optOut
    let lastSchedulerOperationTimestamp: Double?
    let lastSchedulerOperationBrokerUrl: String?
    let lastSchedulerErrorMessage: String?
    let lastSchedulerErrorTimestamp: Double?
    let lastSchedulerSessionStartTimestamp: Double?
    let agentSchedulerState: String? // stopped, running or idle
    let lastStartedSchedulerOperationType: String?
    let lastStartedSchedulerOperationTimestamp: Double?
    let lastStartedSchedulerOperationBrokerUrl: String?

    init(lastRunAppVersion: String,
         lastRunAgentVersion: String? = nil,
         isAgentRunning: Bool = false,
         lastSchedulerOperationType: String? = nil,
         lastSchedulerOperationTimestamp: Double? = nil,
         lastSchedulerOperationBrokerUrl: String? = nil,
         lastSchedulerErrorMessage: String? = nil,
         lastSchedulerErrorTimestamp: Double? = nil,
         lastSchedulerSessionStartTimestamp: Double? = nil,
         agentSchedulerState: String? = nil,
         lastStartedSchedulerOperationType: String? = nil,
         lastStartedSchedulerOperationTimestamp: Double? = nil,
         lastStartedSchedulerOperationBrokerUrl: String? = nil) {
        self.lastRunAppVersion = lastRunAppVersion
        self.lastRunAgentVersion = lastRunAgentVersion
        self.isAgentRunning = isAgentRunning
        self.lastSchedulerOperationType = lastSchedulerOperationType
        self.lastSchedulerOperationTimestamp = lastSchedulerOperationTimestamp
        self.lastSchedulerOperationBrokerUrl = lastSchedulerOperationBrokerUrl
        self.lastSchedulerErrorMessage = lastSchedulerErrorMessage
        self.lastSchedulerErrorTimestamp = lastSchedulerErrorTimestamp
        self.lastSchedulerSessionStartTimestamp = lastSchedulerSessionStartTimestamp
        self.agentSchedulerState = agentSchedulerState
        self.lastStartedSchedulerOperationType = lastStartedSchedulerOperationType
        self.lastStartedSchedulerOperationTimestamp = lastStartedSchedulerOperationTimestamp
        self.lastStartedSchedulerOperationBrokerUrl = lastStartedSchedulerOperationBrokerUrl
    }
}

extension DBPUIInitialScanState {
    static var empty: DBPUIInitialScanState {
        .init(resultsFound: [DBPUIDataBrokerProfileMatch](),
              scanProgress: DBPUIScanProgress(currentScans: 0, totalScans: 0, scannedBrokers: []))
    }
}
