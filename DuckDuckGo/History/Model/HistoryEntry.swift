//
//  HistoryEntry.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit

final class HistoryEntry {

    init(identifier: UUID,
         url: URL,
         title: String? = nil,
         failedToLoad: Bool,
         numberOfTotalVisits: Int,
         lastVisit: Date,
         visits: Set<Visit>,
         numberOfTrackersBlocked: Int,
         blockedTrackingEntities: Set<String>,
         trackersFound: Bool) {
        self.identifier = identifier
        self.url = url
        self.title = title
        self.failedToLoad = failedToLoad
        self.numberOfTotalVisits = numberOfTotalVisits
        self.lastVisit = lastVisit
        self.visits = visits
        self.numberOfTrackersBlocked = numberOfTrackersBlocked
        self.blockedTrackingEntities = blockedTrackingEntities
        self.trackersFound = trackersFound
    }

    let identifier: UUID
    let url: URL
    var title: String?
    var failedToLoad: Bool

    // MARK: - Visits

    // Kept here because of migration. Can be used as computed property once visits of HistoryEntryMO are filled with all necessary info
    // (In use for 1 month by majority of users)
    var numberOfTotalVisits: Int
    var lastVisit: Date

    var visits: Set<Visit>

    func addVisit() {
        let visit = Visit(date: Date(), historyEntry: self)
        visits.insert(visit)

        numberOfTotalVisits += 1
        lastVisit = Date.startOfMinuteNow
    }

    // Used for migration
    func addOldVisit(date: Date) {
        let visit = Visit(date: date, historyEntry: self)
        visits.insert(visit)
    }

    // MARK: - Tracker blocking info

    var numberOfTrackersBlocked: Int
    var blockedTrackingEntities: Set<String>
    var trackersFound: Bool

    func addBlockedTracker(entityName: String) {
        numberOfTrackersBlocked += 1

        guard !entityName.trimWhitespace().isEmpty else {
            return
        }
        blockedTrackingEntities.insert(entityName)
    }

}

extension HistoryEntry {

    convenience init(url: URL) {
        self.init(identifier: UUID(),
                  url: url,
                  title: nil,
                  failedToLoad: false,
                  numberOfTotalVisits: 0,
                  lastVisit: Date.startOfMinuteNow,
                  visits: Set<Visit>(),
                  numberOfTrackersBlocked: 0,
                  blockedTrackingEntities: Set<String>(),
                  trackersFound: false)
    }

}

extension HistoryEntry: Hashable {

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}

extension HistoryEntry: Identifiable {}
