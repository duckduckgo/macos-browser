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

struct HistoryEvent: Sendable {
    enum EventType {
        case noMatchFound
        case matchFound(extractedProfileID: UUID)
        case error
        case optOutStarted(extractedProfileID: UUID)
        case optOutRequested(extractedProfileID: UUID)
        case optOutConfirmed(extractedProfileID: UUID)
        case scanStarted
    }

    let id: UUID
    let type: EventType
    let date: Date

    init(type: EventType) {
        self.id = UUID()
        self.date = Date()
        self.type = type
    }
}

extension HistoryEvent.EventType: Equatable {
    static func ==(lhs: HistoryEvent.EventType, rhs: HistoryEvent.EventType) -> Bool {
        switch (lhs, rhs) {
        case (.noMatchFound, .noMatchFound),
             (.error, .error),
             (.scanStarted, .scanStarted):
            return true
        case let (.matchFound(extractedProfileID: lhsProfileID), .matchFound(extractedProfileID: rhsProfileID)),
             let (.optOutStarted(extractedProfileID: lhsProfileID), .optOutStarted(extractedProfileID: rhsProfileID)),
             let (.optOutRequested(extractedProfileID: lhsProfileID), .optOutRequested(extractedProfileID: rhsProfileID)),
             let (.optOutConfirmed(extractedProfileID: lhsProfileID), .optOutConfirmed(extractedProfileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        default:
            return false
        }
    }
}
