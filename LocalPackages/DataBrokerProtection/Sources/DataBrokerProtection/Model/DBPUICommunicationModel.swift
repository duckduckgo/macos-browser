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

protocol DBPUIMessageContent {
    func toJSONString() -> String
}

struct DBPUIMessage {
    let version: Int
    let name: String
    let content: DBPUIMessageContent
}

public enum DBPUIState: String, Codable {
    case onboarding = "Onboarding"
    case profileReview = "ProfileReview"
    case dashboard = "Dashboard"
}

struct DBPUISetState: Codable {
    let state: DBPUIState
}

public enum DBPUIScanAndOptOutStatus: String, Codable {
    case notRunning
    case quickScan
    case noProfileMatch
    case removingProfile
    case complete
}

struct UserProfileName: Codable {
    let first: String
    let middle: String
    let last: String
}

struct UserProfileAddress: Codable {
    let street: String
    let city: String
    let state: String
}

struct UserProfile: DBPUIMessageContent, Codable {
    let names: [UserProfileName]
    let birthYear: Int
    let addresses: [UserProfileAddress]
    
    func toJSONString() -> String {
        return ""
    }
}

struct DBPUIIndex: Codable {
    let index: Int
}

struct DBPUIDataBroker: Codable {
    let name: String
}

struct DBPUIBirthYear: Codable {
    let year: Int
}

struct DataBrokerProfileMatch: Codable {
    let dataBroker: DBPUIDataBroker
    let names: [UserProfileName]
    let addresses: [UserProfileAddress]
}

struct ScanAndOptOutState: DBPUIMessageContent, Codable {
    let status: DBPUIScanAndOptOutStatus
    let inProgressOptOuts: [DataBrokerProfileMatch]
    let completedOptOuts: [DataBrokerProfileMatch]
    
    func toJSONString() -> String {
        return ""
    }
}
