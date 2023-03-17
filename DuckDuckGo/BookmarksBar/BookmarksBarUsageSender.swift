//
//  BookmarksBarUsageSender.swift
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

/// Sends a pixel indicating whether the bookmarks bar is in use for the current day.
/// This should be sent at the same time as the ATB check; i.e., when a search is triggered. We deliberately avoid sending pixels at launch.
/// This should be sent at most once per day.
///
/// - Note: This is a temporary pixel, which should be removed no later than April 14 2023.
struct BookmarksBarUsageSender {

    @UserDefaultsWrapper(key: .lastBookmarksBarUsagePixelSendDate, defaultValue: .distantPast)
    private static var lastBookmarksBarUsagePixelSendDate: Date

    @discardableResult
    static func sendBookmarksBarUsagePixel(currentDate: Date = Date(), previousDate: Date = lastBookmarksBarUsagePixelSendDate) -> Bool {
        guard !NSCalendar.current.isDate(currentDate, inSameDayAs: previousDate) else {
            return false
        }

        lastBookmarksBarUsagePixelSendDate = currentDate

        if PersistentAppInterfaceSettings.shared.showBookmarksBar {
            Pixel.fire(.bookmarksBarActive)
        } else {
            Pixel.fire(.bookmarksBarInactive)
        }

        return true
    }

}
