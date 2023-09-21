//
//  DailyPixel.swift
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
import Common

final class DailyPixel {

    public enum PixelFrequency {
        /// Sent once per day. The last timestamp for this pixel is stored and compared to the current date. Pixels of this type will have `_d` appended to their name.
        case dailyOnly

        /// Sent once per day with a `_d` suffix, in addition to every time it is called with a `_c` suffix.
        /// This means a pixel will get sent twice the first time it is called per-day, and subsequent calls that day will only send the `_c` variant.
        /// This is useful in situations where pixels receive spikes in volume, as the daily pixel can be used to determine how many users are actually affected.
        case dailyAndCount
    }

    enum Error: Swift.Error {
        case alreadyFired
    }

    private enum Constant {
        static let dailyPixelStorageIdentifier = "com.duckduckgo.daily.pixel.storage"
    }

    private static let storage: UserDefaults = UserDefaults(suiteName: Constant.dailyPixelStorageIdentifier)!

    static func fire(pixel: Pixel.Event,
                     frequency: PixelFrequency,
                     includeAppVersionParameter includeAppVersion: Bool,
                     withAdditionalParameters params: [String: String] = [:],
                     onComplete: @escaping (Swift.Error?) -> Void = { _ in }) {
        switch frequency {
        case .dailyOnly:
            if !pixel.hasBeenFiredToday(dailyPixelStorage: storage) {
                Pixel.shared?.fire(.dailyPixel(pixel, isFirst: true), withAdditionalParameters: params, includeAppVersionParameter: includeAppVersion)
                updatePixelLastFireDate(pixel: pixel)
            }
        case .dailyAndCount:
            if !pixel.hasBeenFiredToday(dailyPixelStorage: storage) {
                Pixel.shared?.fire(.dailyPixel(pixel, isFirst: true), withAdditionalParameters: params, includeAppVersionParameter: includeAppVersion)
                updatePixelLastFireDate(pixel: pixel)
            }

            Pixel.shared?.fire(.dailyPixel(pixel, isFirst: false), withAdditionalParameters: params, includeAppVersionParameter: includeAppVersion)
        }
    }

    private static func updatePixelLastFireDate(pixel: Pixel.Event) {
        storage.set(Date(), forKey: pixel.name)
    }

}

private extension Pixel.Event {

    func hasBeenFiredToday(dailyPixelStorage: UserDefaults) -> Bool {
        if let lastFireDate = dailyPixelStorage.object(forKey: name) as? Date {
            return Calendar.current.isDate(Date(), inSameDayAs: lastFireDate)
        }

        return false
    }

}
