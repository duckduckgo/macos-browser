//
//  Visit.swift
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

final class Visit: Stored {

    typealias ID = URL

    init(date: Date, identifier: ID? = nil, historyEntry: HistoryEntry? = nil) {
        self.date = date
        self.identifier = identifier
        self.historyEntry = historyEntry
    }

    let date: Date

    var identifier: ID?
    weak var historyEntry: HistoryEntry?

}

extension Visit: Hashable {

    static func == (lhs: Visit, rhs: Visit) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

}

extension Visit: NSCopying {

    func copy(with zone: NSZone? = nil) -> Any {
        let visit = Visit(date: date,
                          identifier: identifier,
                          historyEntry: nil)
        visit.savingState = savingState
        return visit
    }

}
