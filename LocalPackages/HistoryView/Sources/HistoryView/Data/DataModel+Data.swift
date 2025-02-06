//
//  DataModel+Data.swift
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

public extension DataModel {

    struct Query: Codable, Equatable {
        let limit: Int
        let offset: Int
        let term: String
    }

    struct QueryResponse: Codable, Equatable {
        let info: QueryInfo
        let value: [HistoryItem]
    }

    struct QueryInfo: Codable, Equatable {
        let finished: Bool
        let term: String
    }

    struct HistoryItem: Codable, Equatable {
        let dateRelativeDay: String
        let dateShort: String
        let dateTimeOfDay: String
        let domain: String
        let fallbackFaviconText: String
        let time: TimeInterval
        let title: String
        let url: String

        public init(dateRelativeDay: String, dateShort: String, dateTimeOfDay: String, domain: String, fallbackFaviconText: String, time: TimeInterval, title: String, url: String) {
            self.dateRelativeDay = dateRelativeDay
            self.dateShort = dateShort
            self.dateTimeOfDay = dateTimeOfDay
            self.domain = domain
            self.fallbackFaviconText = fallbackFaviconText
            self.time = time
            self.title = title
            self.url = url
        }
    }
}
