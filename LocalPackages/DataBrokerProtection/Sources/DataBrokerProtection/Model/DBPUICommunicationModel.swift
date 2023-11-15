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

/// Message to set the UI state. Sent from the UI to the host
struct DBPUISetState: Codable {
    let state: DBPUIState
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Message Object representing a requested change to the user profile's brith year
struct DBPUIBirthYear: Codable {
    let year: Int
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
}

/// Protocol to represent a message that can be passed from the host to the UI
protocol DBPUISendableMessage: Codable {}

/// Message to set the UI state. Sent from the host to the UI
struct DBPUIWebSetState: DBPUISendableMessage {
    let state: DBPUIState
}

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
}

/// Data representing the initial scan progress
struct DBPUIScanProgress: DBPUISendableMessage {
    let currentScans: Int
    let totalScans: Int
}

/// Data to represent the intial scan state
/// It will show the current scans + total, and the results found
struct DBPUIInitialScanState: DBPUISendableMessage {
    let resultsFound: [DBPUIDataBrokerProfileMatch]
    let scanProgress: DBPUIScanProgress
}

struct DBUIScanDate: DBPUISendableMessage {
    let date: Double
    let dataBrokers: [DBPUIDataBroker]
}

struct DBPUIScanSchedule: DBPUISendableMessage {
    let lastScan: DBUIScanDate
    let nextScan: DBUIScanDate
}

struct DBPUIScanHistory: DBPUISendableMessage {
    let sitesScanned: Int
}

extension DBPUIInitialScanState {
    static var empty: DBPUIInitialScanState {
        .init(resultsFound: [DBPUIDataBrokerProfileMatch](),
              scanProgress: DBPUIScanProgress(currentScans: 0, totalScans: 0))
    }
}
