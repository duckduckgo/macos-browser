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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: HistoryEvent.EventType.CodingKeys.self)
            var allKeys = ArraySlice(container.allKeys)
            guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                throw DecodingError.typeMismatch(HistoryEvent.EventType.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
            }
            switch onlyKey {
            case .noMatchFound:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.NoMatchFoundCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.noMatchFound)
                self = HistoryEvent.EventType.noMatchFound
            case .matchesFound:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.MatchesFoundCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.matchesFound)
                self = HistoryEvent.EventType.matchesFound(count: try nestedContainer.decodeIfPresent(Int.self, forKey: HistoryEvent.EventType.MatchesFoundCodingKeys.count) ?? 0)
            case .error:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.ErrorCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.error)
                self = HistoryEvent.EventType.error(error: try nestedContainer.decode(DataBrokerProtectionError.self, forKey: HistoryEvent.EventType.ErrorCodingKeys.error))
            case .optOutStarted:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.OptOutStartedCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.optOutStarted)
                self = HistoryEvent.EventType.optOutStarted
            case .optOutRequested:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.OptOutRequestedCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.optOutRequested)
                self = HistoryEvent.EventType.optOutRequested
            case .optOutConfirmed:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.OptOutConfirmedCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.optOutConfirmed)
                self = HistoryEvent.EventType.optOutConfirmed
            case .scanStarted:
                let nestedContainer = try container.nestedContainer(keyedBy: HistoryEvent.EventType.ScanStartedCodingKeys.self, forKey: HistoryEvent.EventType.CodingKeys.scanStarted)
                self = HistoryEvent.EventType.scanStarted
            }
        }
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
}
