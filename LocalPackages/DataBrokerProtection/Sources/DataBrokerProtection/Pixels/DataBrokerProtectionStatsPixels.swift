//
//  DataBrokerProtectionStatsPixels.swift
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
import Common
import BrowserServicesKit
import PixelKit

protocol DataBrokerProtectionStatsPixelsRepository {
    func markStatsWeeklyPixelDate()
    func markStatsMonthlyPixelDate()

    func getLatestStatsWeeklyPixelDate() -> Date?
    func getLatestStatsMonthlyPixelDate() -> Date?
}

final class DataBrokerProtectionStatsPixelsUserDefaults: DataBrokerProtectionStatsPixelsRepository {

    enum Consts {
        static let weeklyPixelKey = "macos.browser.data-broker-protection.statsWeeklyPixelKey"
        static let monthlyPixelKey = "macos.browser.data-broker-protection.statsMonthlyPixelKey"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .dbp) {
        self.userDefaults = userDefaults
    }

    func markStatsWeeklyPixelDate() {
        userDefaults.set(Date(), forKey: Consts.weeklyPixelKey)
    }

    func markStatsMonthlyPixelDate() {
        userDefaults.set(Date(), forKey: Consts.monthlyPixelKey)
    }

    func getLatestStatsWeeklyPixelDate() -> Date? {
        userDefaults.object(forKey: Consts.weeklyPixelKey) as? Date
    }

    func getLatestStatsMonthlyPixelDate() -> Date? {
        userDefaults.object(forKey: Consts.monthlyPixelKey) as? Date
    }
}

struct StatsByBroker {
    let dataBrokerURL: String
    let numberOfProfilesFound: Int
    let numberOfOptOutsInProgress: Int
    let numberOfSuccessfulOptOuts: Int
    let numberOfFailureOptOuts: Int
    let numberOfNewMatchesFound: Int
    let numberOfReAppereances: Int
    let durationOfFirstOptOut: Int

    var toWeeklyPixel: DataBrokerProtectionPixels {
        return .dataBrokerMetricsWeeklyStats(dataBrokerURL: dataBrokerURL,
                                             profilesFound: numberOfProfilesFound,
                                             optOutsInProgress: numberOfOptOutsInProgress,
                                             successfulOptOuts: numberOfSuccessfulOptOuts,
                                             failedOptOuts: numberOfFailureOptOuts,
                                             durationOfFirstOptOut: durationOfFirstOptOut,
                                             numberOfNewRecordsFound: numberOfNewMatchesFound,
                                             numberOfReappereances: numberOfReAppereances)
    }

    var toMonthlyPixel: DataBrokerProtectionPixels {
        return .dataBrokerMetricsMonthlyStats(dataBrokerURL: dataBrokerURL,
                                              profilesFound: numberOfProfilesFound,
                                              optOutsInProgress: numberOfOptOutsInProgress,
                                              successfulOptOuts: numberOfSuccessfulOptOuts,
                                              failedOptOuts: numberOfFailureOptOuts,
                                              durationOfFirstOptOut: durationOfFirstOptOut,
                                              numberOfNewRecordsFound: numberOfNewMatchesFound,
                                              numberOfReappereances: numberOfReAppereances)
    }
}

extension Array where Element == StatsByBroker {

    func toWeeklyPixel(durationOfFirstOptOut: Int) -> DataBrokerProtectionPixels {
        let numberOfGlobalProfilesFound = map { $0.numberOfProfilesFound }.reduce(0, +)
        let numberOfGlobalOptOutsInProgress = map { $0.numberOfOptOutsInProgress }.reduce(0, +)
        let numberOfGlobalSuccessfulOptOuts = map { $0.numberOfSuccessfulOptOuts }.reduce(0, +)
        let numberOfGlobalFailureOptOuts = map { $0.numberOfFailureOptOuts }.reduce(0, +)
        let numberOfGlobalNewMatchesFound = map { $0.numberOfNewMatchesFound }.reduce(0, +)

        return .globalMetricsWeeklyStats(profilesFound: numberOfGlobalProfilesFound,
                                         optOutsInProgress: numberOfGlobalOptOutsInProgress,
                                         successfulOptOuts: numberOfGlobalSuccessfulOptOuts,
                                         failedOptOuts: numberOfGlobalFailureOptOuts,
                                         durationOfFirstOptOut: durationOfFirstOptOut,
                                         numberOfNewRecordsFound: numberOfGlobalNewMatchesFound)
    }

    func toMonthlyPixel(durationOfFirstOptOut: Int) -> DataBrokerProtectionPixels {
        let numberOfGlobalProfilesFound = map { $0.numberOfProfilesFound }.reduce(0, +)
        let numberOfGlobalOptOutsInProgress = map { $0.numberOfOptOutsInProgress }.reduce(0, +)
        let numberOfGlobalSuccessfulOptOuts = map { $0.numberOfSuccessfulOptOuts }.reduce(0, +)
        let numberOfGlobalFailureOptOuts = map { $0.numberOfFailureOptOuts }.reduce(0, +)
        let numberOfGlobalNewMatchesFound = map { $0.numberOfNewMatchesFound }.reduce(0, +)

        return .globalMetricsMonthlyStats(profilesFound: numberOfGlobalProfilesFound,
                                          optOutsInProgress: numberOfGlobalOptOutsInProgress,
                                          successfulOptOuts: numberOfGlobalSuccessfulOptOuts,
                                          failedOptOuts: numberOfGlobalFailureOptOuts,
                                          durationOfFirstOptOut: durationOfFirstOptOut,
                                          numberOfNewRecordsFound: numberOfGlobalNewMatchesFound)
    }
}

final class DataBrokerProtectionStatsPixels {
    private let database: DataBrokerProtectionRepository
    private let handler: EventMapping<DataBrokerProtectionPixels>
    private let repository: DataBrokerProtectionStatsPixelsRepository
    private let calendar = Calendar.current

    init(database: DataBrokerProtectionRepository,
         handler: EventMapping<DataBrokerProtectionPixels>,
         repository: DataBrokerProtectionStatsPixelsRepository = DataBrokerProtectionStatsPixelsUserDefaults()) {
        self.database = database
        self.handler = handler
        self.repository = repository
    }

    func tryToFireStatsPixels() {
        guard let brokerProfileQueryData = try? database.fetchAllBrokerProfileQueryData() else {
            return
        }

        let dateOfFirstScan = dateOfFirstScan(brokerProfileQueryData)

        if shouldFireWeeklyStats(dateOfFirstScan: dateOfFirstScan) {
            firePixels(for: brokerProfileQueryData, frequency: .weekly)
            repository.markStatsWeeklyPixelDate()
        }

        if shouldFireMonthlyStats(dateOfFirstScan: dateOfFirstScan) {
            firePixels(for: brokerProfileQueryData, frequency: .monthly)
            repository.markStatsMonthlyPixelDate()
        }
    }

    private func shouldFireWeeklyStats(dateOfFirstScan: Date?) -> Bool {
        // If no initial scan was done yet, we do not want to fire the pixel.
        guard let dateOfFirstScan = dateOfFirstScan else {
            return false
        }

        if let lastWeeklyUpdateDate = repository.getLatestStatsWeeklyPixelDate() {
            // If the last weekly was set we need to compare the date with it.
            return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: lastWeeklyUpdateDate, endDate: Date(), daysDifference: .weekly)
        } else {
            // If the weekly update date was never set we need to check the first scan date.
            return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: dateOfFirstScan, endDate: Date(), daysDifference: .weekly)
        }
    }

    private func shouldFireMonthlyStats(dateOfFirstScan: Date?) -> Bool {
        // If no initial scan was done yet, we do not want to fire the pixel.
        guard let dateOfFirstScan = dateOfFirstScan else {
            return false
        }

        if let lastMonthlyUpdateDate = repository.getLatestStatsMonthlyPixelDate() {
            // If the last monthly was set we need to compare the date with it.
            return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: lastMonthlyUpdateDate, endDate: Date(), daysDifference: .monthly)
        } else {
            // If the monthly update date was never set we need to check the first scan date.
            return DataBrokerProtectionPixelsUtilities.shouldWeFirePixel(startDate: dateOfFirstScan, endDate: Date(), daysDifference: .monthly)
        }
    }

    private func firePixels(for brokerProfileQueryData: [BrokerProfileQueryData], frequency: Frequency) {
        let statsByBroker = calculateStatsByBroker(brokerProfileQueryData)

        fireGlobalStats(statsByBroker, brokerProfileQueryData: brokerProfileQueryData, frequency: frequency)
        fireStatsByBroker(statsByBroker, frequency: frequency)
    }

    private func calculateStatsByBroker(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> [StatsByBroker] {
        let profileQueriesGroupedByBroker = Dictionary(grouping: brokerProfileQueryData, by: { $0.dataBroker })
        let statsByBroker = profileQueriesGroupedByBroker.map { (key: DataBroker, value: [BrokerProfileQueryData]) in
            calculateByBroker(key, data: value)
        }

        return statsByBroker
    }

    private func fireGlobalStats(_ stats: [StatsByBroker], brokerProfileQueryData: [BrokerProfileQueryData], frequency: Frequency) {
        // The duration for the global stats is calculated not taking into the account the broker. That's why we do not use one from the stats.
        let durationOfFirstOptOut = calculateDurationOfFirstOptOut(brokerProfileQueryData)

        switch frequency {
        case .weekly:
            handler.fire(stats.toWeeklyPixel(durationOfFirstOptOut: durationOfFirstOptOut))
        case .monthly:
            handler.fire(stats.toMonthlyPixel(durationOfFirstOptOut: durationOfFirstOptOut))
        default: ()
        }
    }

    private func fireStatsByBroker(_ stats: [StatsByBroker], frequency: Frequency) {
        for stat in stats {
            switch frequency {
            case .weekly:
                handler.fire(stat.toWeeklyPixel)
            case .monthly:
                handler.fire(stat.toMonthlyPixel)
            default: ()
            }
        }
    }

    /// internal for testing purposes
    func calculateByBroker(_ broker: DataBroker, data: [BrokerProfileQueryData]) -> StatsByBroker {
        let mirrorSitesSize = broker.mirrorSites.count
        var numberOfProfilesFound = 0 // Number of unique matching profiles found since the beginning.
        var numberOfOptOutsInProgress = 0 // Number of opt-outs in progress since the beginning.
        var numberOfSuccessfulOptOuts = 0 // Number of successfull opt-outs since the beginning
        var numberOfReAppearences = 0 // Number of records that were removed and came back

        for query in data {
            for optOutData in query.optOutJobData {
                if broker.performsOptOutWithinParent() {
                    // Path when the broker is a child site.
                    numberOfProfilesFound += 1
                    if optOutData.historyEvents.contains(where: { $0.type == .optOutConfirmed }) {
                        numberOfSuccessfulOptOuts += 1
                    } else {
                        numberOfOptOutsInProgress += 1
                    }
                } else {
                    // Path when the broker is a parent site.
                    // If we requested the opt-out successfully but we didn't remove it yet, it means it is in progress
                    numberOfProfilesFound += 1 + mirrorSitesSize

                    if optOutData.historyEvents.contains(where: { $0.type == .optOutRequested }) && optOutData.extractedProfile.removedDate == nil {
                        numberOfOptOutsInProgress += 1 + mirrorSitesSize
                    } else if optOutData.extractedProfile.removedDate != nil { // If it the removed date is not nil, it means we removed it.
                        numberOfSuccessfulOptOuts += 1 + mirrorSitesSize
                    }
                }
            }

            numberOfReAppearences += calculateNumberOfReAppereances(query.scanJobData) + mirrorSitesSize
        }

        let numberOfFailureOptOuts = numberOfProfilesFound - numberOfOptOutsInProgress - numberOfSuccessfulOptOuts
        let numberOfNewMatchesFound = calculateNumberOfNewMatchesFound(data)
        let durationOfFirstOptOut = calculateDurationOfFirstOptOut(data)

        return StatsByBroker(dataBrokerURL: broker.url,
                             numberOfProfilesFound: numberOfProfilesFound,
                             numberOfOptOutsInProgress: numberOfOptOutsInProgress,
                             numberOfSuccessfulOptOuts: numberOfSuccessfulOptOuts,
                             numberOfFailureOptOuts: numberOfFailureOptOuts,
                             numberOfNewMatchesFound: numberOfNewMatchesFound,
                             numberOfReAppereances: numberOfReAppearences,
                             durationOfFirstOptOut: durationOfFirstOptOut)
    }

    /// Calculates number of new matches found on scans that were not initial scans.
    ///
    /// internal for testing purposes
    func calculateNumberOfNewMatchesFound(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> Int {
        var numberOfNewMatches = 0

        let brokerProfileQueryDataWithAMatch = brokerProfileQueryData.filter { !$0.extractedProfiles.isEmpty }
        let profileQueriesGroupedByBroker = Dictionary(grouping: brokerProfileQueryDataWithAMatch, by: { $0.dataBroker })

        profileQueriesGroupedByBroker.forEach { (key: DataBroker, value: [BrokerProfileQueryData]) in
            let mirrorSitesCount = key.mirrorSites.count

            for query in value {
                let matchesFoundEvents = query.scanJobData.historyEvents
                    .filter { $0.isMatchEvent() }
                    .sorted { $0.date < $1.date }

                matchesFoundEvents.enumerated().forEach { index, element in
                    if index > 0 && index < matchesFoundEvents.count - 1 {
                        let nextElement = matchesFoundEvents[index + 1]
                        numberOfNewMatches += max(nextElement.matchesFound() - element.matchesFound(), 0)
                    }
                }

                if numberOfNewMatches > 0 {
                    numberOfNewMatches += mirrorSitesCount
                }
            }
        }

        return numberOfNewMatches
    }

    private func calculateNumberOfReAppereances(_ scan: ScanJobData) -> Int {
        return scan.historyEvents.filter { $0.type == .reAppearence }.count
    }

    /// Calculate the difference in days since the first scan and the first submitted opt-out for the list of brokerProfileQueryData.
    /// The scan and the opt-out do not need to be for the same record.
    /// If an opt-out wasn't submitted yet, we return 0.
    ///
    /// internal for testing purposes
    func calculateDurationOfFirstOptOut(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> Int {        guard let dateOfFirstScan = dateOfFirstScan(brokerProfileQueryData),
              let dateOfFirstSubmittedOptOut = dateOfFirstSubmittedOptOut(brokerProfileQueryData) else {
            return 0
        }

        if dateOfFirstScan > dateOfFirstSubmittedOptOut {
            return 0
        }

        guard let differenceInDays = DataBrokerProtectionPixelsUtilities.differenceBetweenDates(startDate: dateOfFirstScan, endDate: dateOfFirstSubmittedOptOut) else {
            return 0
        }

        // If the difference in days is in hours, return 1.
        if differenceInDays == 0 {
            return 1
        }

        return differenceInDays
    }

    /// Returns the date of the first scan
    private func dateOfFirstScan(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> Date? {
        let allScanOperations = brokerProfileQueryData.map { $0.scanJobData }
        let allScanHistoryEvents = allScanOperations.flatMap { $0.historyEvents }
        let scanStartedEventsSortedByDate = allScanHistoryEvents
            .filter { $0.type == .scanStarted }
            .sorted { $0.date < $1.date }

        return scanStartedEventsSortedByDate.first?.date
    }

    /// Returns the date of the first sumbitted opt-out
    private func dateOfFirstSubmittedOptOut(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> Date? {
        let firstOptOutSubmittedEvent = brokerProfileQueryData
            .flatMap { $0.optOutJobData }
            .flatMap { $0.historyEvents }
            .filter { $0.type == .optOutRequested }
            .sorted { $0.date < $1.date }
            .first

        return firstOptOutSubmittedEvent?.date
    }
}
