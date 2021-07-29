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

struct HistoryEntry {

    let identifier: UUID
    let url: URL
    var title: String?
    var numberOfVisits: Int
    var lastVisit: Date
    var failedToLoad: Bool
    var isDownload: Bool

    mutating func addVisit() {
        numberOfVisits += 1
        lastVisit = Date.startOfDayToday
    }

}

extension HistoryEntry {

    init(url: URL) {
        self.init(identifier: UUID(),
                  url: url,
                  title: nil,
                  numberOfVisits: 0,
                  lastVisit: Date.startOfDayToday,
                  failedToLoad: false,
                  isDownload: false)
    }

}

extension HistoryEntry: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier.hashValue)
    }

}
