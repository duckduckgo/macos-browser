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
        case matchFound(profileID: UUID)
        case error
        case optOutStarted(profileID: UUID)
        case optOutRequested(profileID: UUID)
        case optOutConfirmed(profileID: UUID)
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
