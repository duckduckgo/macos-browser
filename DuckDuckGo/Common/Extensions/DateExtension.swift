//
//  DateExtension.swift
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

extension Date {

    struct IndexedMonth: Hashable {
        let name: String
        let index: Int
    }

    var components: DateComponents {
        return Calendar.current.dateComponents([.day, .year, .month], from: self)
    }

    static var weekAgo: Date {
        return Calendar.current.date(byAdding: .weekOfMonth, value: -1, to: Date())!
    }

    static var monthAgo: Date! {
        return Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    }

    static func daysAgo(_ days: Int) -> Date! {
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    static var startOfDayTomorrow: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.startOfDay(for: tomorrow)
    }

    static var startOfDayToday: Date {
        return Calendar.current.startOfDay(for: Date())
    }

    var startOfDay: Date {
        return  Calendar.current.startOfDay(for: self)
    }

    static var startOfMinuteNow: Date {
        let date = Calendar.current.date(bySetting: .second, value: 0, of: Date())!
        let start = Calendar.current.date(byAdding: .minute, value: -1, to: date)!
        return start
    }

    static var monthsWithIndex: [IndexedMonth] {
        let months = Calendar.current.monthSymbols

        return months.enumerated().map { index, month in
            return IndexedMonth(name: month, index: index + 1)
        }
    }

    static var daysInMonth: [Int] = {
        return Array(1...31)
    }()

    static var nextTenYears: [Int] = {
        let offsetComponents = DateComponents(year: 1)

        var years = [Int]()
        var currentDate = Date()

        for _ in 0...10 {
            let currentYear = Calendar.current.component(.year, from: currentDate)
            years.append(currentYear)

            currentDate = Calendar.current.date(byAdding: offsetComponents, to: currentDate)!
        }

        return years
    }()

    static var lastHundredYears: [Int] = {
        let offsetComponents = DateComponents(year: -1)

        var years = [Int]()
        var currentDate = Date()

        for _ in 0...100 {
            let currentYear = Calendar.current.component(.year, from: currentDate)
            years.append(currentYear)

            currentDate = Calendar.current.date(byAdding: offsetComponents, to: currentDate)!
        }

        return years
    }()

    var daySinceReferenceDate: Int {
        Int(self.timeIntervalSinceReferenceDate / TimeInterval.day)
    }

    @inlinable
    func adding(_ timeInterval: TimeInterval) -> Date {
        addingTimeInterval(timeInterval)
    }

}
