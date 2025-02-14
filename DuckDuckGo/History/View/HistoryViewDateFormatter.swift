//
//  HistoryViewDateFormatter.swift
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

protocol HistoryViewDateFormatting {
    func weekDay(for date: Date) -> String
    func time(for date: Date) -> String
}

struct DefaultHistoryViewDateFormatter: HistoryViewDateFormatting {
    let weekDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "cccc"
        return formatter
    }()

    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    func weekDay(for date: Date) -> String {
        weekDayFormatter.string(from: date)
    }

    func time(for date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
