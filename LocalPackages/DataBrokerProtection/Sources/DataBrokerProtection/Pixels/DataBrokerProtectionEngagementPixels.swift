//
//  DataBrokerProtectionEngagementPixels.swift
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
import os.log
import BrowserServicesKit
import PixelKit
import Common

protocol DataBrokerProtectionEngagementPixelsRepository {
    func markDailyPixelSent()
    func markWeeklyPixelSent()
    func markMonthlyPixelSent()

    func getLatestDailyPixel() -> Date?
    func getLatestWeeklyPixel() -> Date?
    func getLatestMonthlyPixel() -> Date?
}

final class DataBrokerProtectionEngagementPixelsUserDefaults: DataBrokerProtectionEngagementPixelsRepository {

    enum Consts {
        static let dailyPixelKey = "macos.browser.data-broker-protection.dailyPixelKey"
        static let weeklyPixelKey = "macos.browser.data-broker-protection.weeklyPixelKey"
        static let monthlyPixelKey = "macos.browser.data-broker-protection.monthlyPixelKey"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func markDailyPixelSent() {
        userDefaults.set(Date(), forKey: Consts.dailyPixelKey)
    }

    func markWeeklyPixelSent() {
        userDefaults.set(Date(), forKey: Consts.weeklyPixelKey)
    }

    func markMonthlyPixelSent() {
        userDefaults.set(Date(), forKey: Consts.monthlyPixelKey)
    }

    func getLatestDailyPixel() -> Date? {
        userDefaults.object(forKey: Consts.dailyPixelKey) as? Date
    }

    func getLatestWeeklyPixel() -> Date? {
        userDefaults.object(forKey: Consts.weeklyPixelKey) as? Date
    }

    func getLatestMonthlyPixel() -> Date? {
        userDefaults.object(forKey: Consts.monthlyPixelKey) as? Date
    }

}

/*
 https://app.asana.com/0/1204586965688315/1206648312655381/f

 1. When a user becomes an "Active User" of your feature, immediately fire individual pixels to register a DAU, a WAU and a MAU. Record (on-device) the date that the pixel was fired for each of the three events. e.g.
   - DAU Pixel Last Sent 2024-02-20
   - WAU Pixel Last Sent 2024-02-20
   - MAU Pixel Last Sent 2024-02-20
 2. If it is >= 1 date since the DAU pixel was last sent, send a new DAU pixel, and update the date with the current date
   - DAU Pixel Last Sent 2024-02-21
   - WAU Pixel Last Sent 2024-02-20
   - MAU Pixel Last Sent 2024-02-20
 3. If it is >= 7 dates since the WAU pixel was last sent, send a new WAU pixel and update the date with the current date
   - DAU Pixel Last Sent 2024-02-27
   - WAU Pixel Last Sent 2024-02-27
   - MAU Pixel Last Sent 2024-02-20
 4. If it is >= 28 dates since the MAU pixel was last sent, send a new MAU pixel and update the date with the current date:
   - DAU Pixel Last Sent 2024-03-19
   - WAU Pixel Last Sent 2024-03-19
   - MAU Pixel Last Sent 2024-03-19
 */
final class DataBrokerProtectionEngagementPixels {
    private let database: DataBrokerProtectionRepository
    private let repository: DataBrokerProtectionEngagementPixelsRepository
    private let handler: EventMapping<DataBrokerProtectionPixels>

    init(database: DataBrokerProtectionRepository,
         handler: EventMapping<DataBrokerProtectionPixels>,
         repository: DataBrokerProtectionEngagementPixelsRepository = DataBrokerProtectionEngagementPixelsUserDefaults()) {
        self.database = database
        self.handler = handler
        self.repository = repository
    }

    func fireEngagementPixel(currentDate: Date = Date()) {
        guard (try? database.fetchProfile()) != nil else {
            Logger.dataBrokerProtection.log("No profile. We do not fire any pixel because we do not consider it an engaged user.")
            return
        }

        if shouldWeFireDailyPixel(date: currentDate) {
            handler.fire(.dailyActiveUser)
            repository.markDailyPixelSent()
        }

        if shouldWeFireWeeklyPixel(date: currentDate) {
            handler.fire(.weeklyActiveUser)
            repository.markWeeklyPixelSent()
        }

        if shouldWeFireMonthlyPixel(date: currentDate) {
            handler.fire(.monthlyActiveUser)
            repository.markMonthlyPixelSent()
        }
    }

    private func shouldWeFireDailyPixel(date: Date) -> Bool {
        guard let latestPixelFire = repository.getLatestDailyPixel() else {
            return true
        }

        return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: latestPixelFire, endDate: date, daysDifference: .daily)
    }

    private func shouldWeFireWeeklyPixel(date: Date) -> Bool {
        guard let latestPixelFire = repository.getLatestWeeklyPixel() else {
            return true
        }

        return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: latestPixelFire, endDate: date, daysDifference: .weekly)
    }

    private func shouldWeFireMonthlyPixel(date: Date) -> Bool {
        guard let latestPixelFire = repository.getLatestMonthlyPixel() else {
            return true
        }

        return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: latestPixelFire, endDate: date, daysDifference: .monthly)
    }
}
