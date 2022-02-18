//
//  HomepageRecentlyVisitedModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

extension Homepage.Models {

final class RecentlyVisitedModel: ObservableObject {

    @Published var numberOfTrackersBlocked = 0
    @Published var numberOfWebsites = 0

    func refreshWithHistory(_ history: [HistoryEntry]) {
        var numberOfTrackersBlocked = 0
        var uniqueSites = Set<String>()

        history.forEach {
            numberOfTrackersBlocked += $0.numberOfTrackersBlocked
            if let host = $0.url.host?.dropWWW() {
                uniqueSites.insert(host)
            }
        }

        self.numberOfTrackersBlocked = numberOfTrackersBlocked
        self.numberOfWebsites = uniqueSites.count
    }

}

}
