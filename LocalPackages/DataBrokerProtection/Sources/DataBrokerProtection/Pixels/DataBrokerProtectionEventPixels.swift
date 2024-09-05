//
//  DataBrokerProtectionEventPixels.swift
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

protocol DataBrokerProtectionEventPixelsRepository {
    func markWeeklyPixelSent()

    func getLatestWeeklyPixel() -> Date?
}

final class DataBrokerProtectionEventPixelsUserDefaults: DataBrokerProtectionEventPixelsRepository {

    enum Consts {
        static let weeklyPixelKey = "macos.browser.data-broker-protection.eventsWeeklyPixelKey"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func markWeeklyPixelSent() {
        userDefaults.set(Date(), forKey: Consts.weeklyPixelKey)
    }

    func getLatestWeeklyPixel() -> Date? {
        userDefaults.object(forKey: Consts.weeklyPixelKey) as? Date
    }
}

final class DataBrokerProtectionEventPixels {

    private let database: DataBrokerProtectionRepository
    private let repository: DataBrokerProtectionEventPixelsRepository
    private let handler: EventMapping<DataBrokerProtectionPixels>
    private let calendar = Calendar.current

    init(database: DataBrokerProtectionRepository,
         repository: DataBrokerProtectionEventPixelsRepository = DataBrokerProtectionEventPixelsUserDefaults(),
         handler: EventMapping<DataBrokerProtectionPixels>) {
        self.database = database
        self.repository = repository
        self.handler = handler
    }

    func tryToFireWeeklyPixels() {
        if shouldWeFireWeeklyPixel() {
            fireWeeklyReportPixels()
            repository.markWeeklyPixelSent()
        }
    }

    func fireNewMatchEventPixel() {
        handler.fire(.scanningEventNewMatch)
    }

    func fireReAppereanceEventPixel() {
        handler.fire(.scanningEventReAppearance)
    }

    private func shouldWeFireWeeklyPixel() -> Bool {
        guard let lastPixelFiredDate = repository.getLatestWeeklyPixel() else {
            return true // Last pixel fired date is not present. We should fire it
        }

        return didWeekPassedBetweenDates(start: lastPixelFiredDate, end: Date())
    }

    private func fireWeeklyReportPixels() {
        let data: [BrokerProfileQueryData]

        do {
            data = try database.fetchAllBrokerProfileQueryData()
        } catch {
            Logger.dataBrokerProtection.error("Database error: when attempting to fireWeeklyReportPixels, error: \(error.localizedDescription, privacy: .public)")
            return
        }
        let dataInThePastWeek = data.filter(hadScanThisWeek(_:))

        var newMatchesFoundInTheLastWeek = 0
        var reAppereancesInTheLastWeek = 0
        var removalsInTheLastWeek = 0

        for query in data {
            let allHistoryEventsForQuery = query.scanJobData.historyEvents + query.optOutJobData.flatMap { $0.historyEvents }
            let historyEventsInThePastWeek = allHistoryEventsForQuery.filter {
                !didWeekPassedBetweenDates(start: $0.date, end: Date())
            }
            let newMatches = historyEventsInThePastWeek.reduce(0, { result, next in
                return result + next.matchesFound()
            })
            let reAppereances = historyEventsInThePastWeek.filter { $0.type == .reAppearence }.count
            let removals = historyEventsInThePastWeek.filter { $0.type == .optOutConfirmed }.count

            newMatchesFoundInTheLastWeek += newMatches
            reAppereancesInTheLastWeek += reAppereances
            removalsInTheLastWeek += removals
        }

        let totalBrokers = Dictionary(grouping: data, by: { $0.dataBroker.url }).count
        let totalBrokersInTheLastWeek = Dictionary(grouping: dataInThePastWeek, by: { $0.dataBroker.url }).count
        var percentageOfBrokersScanned: Int

        if totalBrokers == 0 {
            percentageOfBrokersScanned = 0
        } else {
            percentageOfBrokersScanned = (totalBrokersInTheLastWeek * 100) / totalBrokers
        }

        handler.fire(.weeklyReportScanning(hadNewMatch: newMatchesFoundInTheLastWeek > 0, hadReAppereance: reAppereancesInTheLastWeek > 0, scanCoverage: percentageOfBrokersScanned.toString))
        handler.fire(.weeklyReportRemovals(removals: removalsInTheLastWeek))
    }

    private func hadScanThisWeek(_ brokerProfileQuery: BrokerProfileQueryData) -> Bool {
        return brokerProfileQuery.scanJobData.historyEvents.contains { historyEvent in
            !didWeekPassedBetweenDates(start: historyEvent.date, end: Date())
        }
    }

    private func didWeekPassedBetweenDates(start: Date, end: Date) -> Bool {
        let components = calendar.dateComponents([.day], from: start, to: end)

        if let differenceInDays = components.day {
            return differenceInDays >= 7
        } else {
            return false
        }
    }
}

private extension Int {
    var toString: String {
        if self < 25 {
            return "0-25"
        } else if self < 50 {
            return "25-50"
        } else if self < 75 {
            return "50-75"
        } else if self <= 100 {
            return "75-100"
        } else {
            return "error"
        }
    }
}
