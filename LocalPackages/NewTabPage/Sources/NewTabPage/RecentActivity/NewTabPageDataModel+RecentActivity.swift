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
        let id: String
        let title: String
        let url: String
        let etldPlusOne: String?
        let favicon: String?
        let favorite: Bool
        let trackingStatus: TrackingStatus
        let history: [HistoryEntry]
    }

    struct TrackingStatus: Encodable, Equatable {
        let totalCount: Int64
        let trackerCompanies: [TrackerCompany]

        struct TrackerCompany: Encodable, Equatable {
            let displayName: String
        }
    }

    struct HistoryEntry: Encodable, Equatable {
        let relativeTime: String
        /// This is the displayed name, which on macOS is equal to the relative URL path, e.g. '/users/settings', '/v2/api/analytics'
        let title: String
        let url: String
    }
}

extension NewTabPageDataModel {

    struct ActivityOpenAction: Decodable, Equatable {
        let id: String?
        let target: OpenTarget
        let url: String

        enum OpenTarget: String, Decodable {
            case sameTab = "same-tab"
            case newTab = "new-tab"
            case newWindow = "new-window"
        }
    }
}
