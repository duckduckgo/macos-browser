//
//  DataModel.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

public enum DataModel {

    public struct HistoryItemsBatch: Codable, Equatable {
        let finished: Bool
        let visits: [HistoryItem]

        public init(finished: Bool, visits: [HistoryItem]) {
            self.finished = finished
            self.visits = visits
        }
    }

    public enum HistoryRange: String, Codable {
        case all
        case today
        case yesterday
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case sunday
        case older
        case recentlyOpened
    }

    public enum HistoryQueryKind: Codable, Equatable {
        case searchTerm(String)
        case domainFilter(String)
        case rangeFilter(HistoryRange)

        enum CodingKeys: CodingKey {
            case term, range, domain
        }

        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            if let term = try container.decodeIfPresent(String.self, forKey: CodingKeys.term) {
                self = .searchTerm(term)
            } else if let domain = try container.decodeIfPresent(String.self, forKey: CodingKeys.domain) {
                self = .domainFilter(domain)
            } else if let range = try container.decodeIfPresent(HistoryRange.self, forKey: CodingKeys.range) {
                self = .rangeFilter(range)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unkown query kind"))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .searchTerm(let searchTerm):
                try container.encode(searchTerm, forKey: CodingKeys.term)
            case .domainFilter(let domain):
                try container.encode(domain, forKey: CodingKeys.domain)
            case .rangeFilter(let range):
                try container.encode(range, forKey: CodingKeys.range)
            }
        }
    }

    public struct HistoryQuery: Codable, Equatable {
        let query: HistoryQueryKind
        let limit: Int
        let offset: Int

        public init(query: HistoryQueryKind, limit: Int, offset: Int) {
            self.query = query
            self.limit = limit
            self.offset = offset
        }
    }

    public struct HistoryItem: Codable, Equatable {
        public let id: String
        public let url: String
        public let title: String

        public let domain: String
        public let etldPlusOne: String?

        public let dateRelativeDay: String
        public let dateShort: String
        public let dateTimeOfDay: String

        public init(id: String, url: String, title: String, domain: String, etldPlusOne: String?, dateRelativeDay: String, dateShort: String, dateTimeOfDay: String) {
            self.id = id
            self.url = url
            self.title = title
            self.domain = domain
            self.etldPlusOne = etldPlusOne
            self.dateRelativeDay = dateRelativeDay
            self.dateShort = dateShort
            self.dateTimeOfDay = dateTimeOfDay
        }
    }
}

extension DataModel {

    struct Configuration: Encodable {
        var env: String
        var locale: String
        var platform: Platform

        struct Platform: Encodable, Equatable {
            var name: String
        }
    }

    struct Exception: Codable, Equatable {
        let message: String
    }

    struct GetRangesResponse: Codable, Equatable {
        let ranges: [HistoryRange]
    }

    struct HistoryQueryInfo: Codable, Equatable {
        let finished: Bool
        let query: HistoryQueryKind
    }

    struct HistoryQueryResponse: Codable, Equatable {
        let info: HistoryQueryInfo
        let value: [HistoryItem]
    }

    struct HistoryOpenAction: Codable {
        let url: String
    }
}
