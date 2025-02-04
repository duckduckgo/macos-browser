//
//  NewTabPageDataModel+RecentActivity.swift
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

public extension NewTabPageDataModel {

    struct ActivityData: Encodable, Equatable {
        let activity: [DomainActivity]
    }

    struct DomainActivity: Encodable, Equatable {
        public var id: String
        public var title: String
        public var url: String
        public var etldPlusOne: String?
        public var favicon: ActivityFavicon?
        public var favorite: Bool
        public var trackersFound: Bool
        public var trackingStatus: TrackingStatus
        public var history: [HistoryEntry]

        public init(id: String, title: String, url: String, etldPlusOne: String?, favicon: ActivityFavicon?, favorite: Bool, trackersFound: Bool, trackingStatus: TrackingStatus, history: [HistoryEntry]) {
            self.id = id
            self.title = title
            self.url = url
            self.etldPlusOne = etldPlusOne
            self.favicon = favicon
            self.favorite = favorite
            self.trackersFound = trackersFound
            self.trackingStatus = trackingStatus
            self.history = history
        }
    }

    struct ActivityFavicon: Encodable, Equatable {
        let maxAvailableSize: Int
        let src: String

        public init(maxAvailableSize: Int, src: String) {
            self.maxAvailableSize = maxAvailableSize
            self.src = src
        }
    }

    struct TrackingStatus: Encodable, Equatable {
        public var totalCount: Int64
        public var trackerCompanies: [TrackerCompany]

        public init(totalCount: Int64, trackerCompanies: [TrackerCompany]) {
            self.totalCount = totalCount
            self.trackerCompanies = trackerCompanies
        }

        public struct TrackerCompany: Encodable, Equatable, Hashable {
            public let displayName: String

            public init(displayName: String) {
                self.displayName = displayName
            }
        }
    }

    struct HistoryEntry: Encodable, Equatable {
        public var relativeTime: String
        /// This is the displayed name, which on macOS is equal to the relative URL path, e.g. '/users/settings', '/v2/api/analytics'
        public var title: String
        public var url: String

        public init(relativeTime: String, title: String, url: String) {
            self.relativeTime = relativeTime
            self.title = title
            self.url = url
        }
    }
}

extension NewTabPageDataModel {

    struct ActivityOpenAction: Codable, Equatable {
        let id: String?
        let target: OpenTarget
        let url: String

        enum OpenTarget: String, Codable {
            case sameTab = "same-tab"
            case newTab = "new-tab"
            case newWindow = "new-window"
        }
    }

    struct ActivityItemAction: Codable, Equatable {
        let url: String
    }

    struct ConfirmBurnResponse: Codable, Equatable {
        let action: Action

        enum Action: String, Codable {
            case burn, none
        }
    }
}
