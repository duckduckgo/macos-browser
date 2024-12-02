//
//  HistoryEvent.swift
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

public struct HistoryEvent: Identifiable, Sendable {
    public enum EventType: Codable, Equatable, Sendable {
        case noMatchFound
        case matchesFound(count: Int)
        case error(error: DataBrokerProtectionError)
        case optOutStarted
        case optOutRequested
        case optOutConfirmed
        case scanStarted
        case reAppearence
    }

    public let extractedProfileId: Int64?
    public let brokerId: Int64
    public let profileQueryId: Int64
    public let type: EventType
    public let date: Date

    public var id: String {
        return "\(extractedProfileId ?? 0)-\(brokerId)-\(profileQueryId)-\(date)"
    }

    init(extractedProfileId: Int64? = nil,
         brokerId: Int64,
         profileQueryId: Int64,
         type: EventType,
         date: Date = Date()) {
        self.extractedProfileId = extractedProfileId
        self.brokerId = brokerId
        self.profileQueryId = profileQueryId
        self.date = date
        self.type = type
    }

    func matchesFound() -> Int {
        switch type {
        case .matchesFound(let matchesFound):
            return matchesFound
        default:
            return 0
        }
    }

    func isMatchEvent() -> Bool {
        switch type {
        case .noMatchFound, .matchesFound:
            return true
        default:
            return false
        }
    }

    func isMatchesFoundEvent() -> Bool {
        switch type {
        case .matchesFound:
            return true
        default:
            return false
        }
    }
}
