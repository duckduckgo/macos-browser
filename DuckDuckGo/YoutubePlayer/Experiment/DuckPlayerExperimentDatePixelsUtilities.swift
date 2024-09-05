//
//  DuckPlayerExperimentDatePixelsUtilities.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

enum Frequency: Int {
    case daily = 1
    case weekly = 7
}

struct DuckPlayerExperimentDatePixelsUtilities {
    private static let calendar = Calendar.current

    /// Determines whether a pixel should fire based on the start and end dates and the specified frequency.
    ///
    /// - Parameters:
    ///   - startDate: The date from which to start the calculation.
    ///   - endDate: The date at which to end the calculation.
    ///   - daysDifference: The frequency that determines the minimum number of days required to fire the pixel.
    /// - Returns: A Boolean value indicating whether the pixel should fire.
    static func shouldFirePixel(startDate: Date, endDate: Date, daysDifference: Frequency) -> Bool {
        if let differenceBetweenDates = numberOfDaysFrom(startDate: startDate, endDate: endDate) {
            return differenceBetweenDates >= daysDifference.rawValue
        }

        return false
    }

    /// Calculates the number of days between two dates.
    ///
    /// - Parameters:
    ///   - startDate: The starting date for the calculation.
    ///   - endDate: The ending date for the calculation.
    /// - Returns: The number of days between the two dates, or `nil` if the calculation fails.
    static func numberOfDaysFrom(startDate: Date, endDate: Date) -> Int? {
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day
    }
}
