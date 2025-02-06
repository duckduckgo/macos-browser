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

    var customStatsPixelsLastSentTimestamp: Date? { get set }

    func markStatsWeeklyPixelDate()
    func markStatsMonthlyPixelDate()

    func getLatestStatsWeeklyPixelDate() -> Date?
    func getLatestStatsMonthlyPixelDate() -> Date?
}

final class DataBrokerProtectionStatsPixelsUserDefaults: DataBrokerProtectionStatsPixelsRepository {

    enum Consts {
        static let weeklyPixelKey = "macos.browser.data-broker-protection.statsWeeklyPixelKey"
        static let monthlyPixelKey = "macos.browser.data-broker-protection.statsMonthlyPixelKey"
        static let customStatsPixelKey = "macos.browser.data-broker-protection.customStatsPixelKey"
    }

    private let userDefaults: UserDefaults

    var customStatsPixelsLastSentTimestamp: Date? {
        get {
            userDefaults.object(forKey: Consts.customStatsPixelKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Consts.customStatsPixelKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
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

protocol StatsPixels {
    /// Calculates and fires custom stats pixels if needed
    func fireCustomStatsPixelsIfNeeded()
}

/// Conforming types provide a method to check if we should fire custom stats based on an input date
protocol CustomStatsPixelsTrigger {

    /// This method determines whether custom stats pixels should be fired based on the time interval since the provided fromDate.
    /// - Parameter fromDate: An optional date parameter representing the start date. If nil, the method will return true.
    /// - Returns: Returns true if more than 24 hours have passed since the fromDate. If fromDate is nil, it also returns true. Otherwise, it returns false.
    func shouldFireCustomStatsPixels(fromDate: Date?) -> Bool
}

struct DefaultCustomStatsPixelsTrigger: CustomStatsPixelsTrigger {

    func shouldFireCustomStatsPixels(fromDate: Date?) -> Bool {
        guard let fromDate = fromDate else { return true }

        let interval = Date().timeIntervalSince(fromDate)
        let secondsIn24Hours: TimeInterval = 24 * 60 * 60
        return abs(interval) > secondsIn24Hours
    }
}

extension Date {

    /// Returns the current date minus the specified number of hours
    /// If the date calculate fails, returns the current date
    /// - Parameter hours: Hours expressed as an integer
    /// - Returns: The current time minus the specified number of hours
    static func nowMinus(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
    }

    static func nowPlus(hours: Int) -> Date {
        nowMinus(hours: -hours)
    }
}

final class DataBrokerProtectionStatsPixels: StatsPixels {

    private let database: DataBrokerProtectionRepository
    private let handler: EventMapping<DataBrokerProtectionPixels>
    private var repository: DataBrokerProtectionStatsPixelsRepository
    private let customStatsPixelsTrigger: CustomStatsPixelsTrigger
    private let customOptOutStatsProvider: DataBrokerProtectionCustomOptOutStatsProvider
    private let calendar = Calendar.current

    init(database: DataBrokerProtectionRepository,
         handler: EventMapping<DataBrokerProtectionPixels>,
         repository: DataBrokerProtectionStatsPixelsRepository = DataBrokerProtectionStatsPixelsUserDefaults(),
         customStatsPixelsTrigger: CustomStatsPixelsTrigger = DefaultCustomStatsPixelsTrigger(),
         customOptOutStatsProvider: DataBrokerProtectionCustomOptOutStatsProvider = DefaultDataBrokerProtectionCustomOptOutStatsProvider()) {
        self.database = database
        self.handler = handler
        self.repository = repository
        self.customStatsPixelsTrigger = customStatsPixelsTrigger
        self.customOptOutStatsProvider = customOptOutStatsProvider
    }

    func tryToFireStatsPixels() {
        guard let brokerProfileQueryData = try? database.fetchAllBrokerProfileQueryData() else {
            return
        }

        let dateOfFirstScan = dateOfFirstScan(brokerProfileQueryData)

        if shouldFireWeeklyStats(dateOfFirstScan: dateOfFirstScan) {
            firePixels(for: brokerProfileQueryData,
                       frequency: .weekly,
                       dateSinceLastSubmission: repository.getLatestStatsWeeklyPixelDate())
            repository.markStatsWeeklyPixelDate()
        }

        if shouldFireMonthlyStats(dateOfFirstScan: dateOfFirstScan) {
            firePixels(for: brokerProfileQueryData,
                       frequency: .monthly,
                       dateSinceLastSubmission: repository.getLatestStatsMonthlyPixelDate())
            repository.markStatsMonthlyPixelDate()
        }

        fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for: brokerProfileQueryData)
    }

    func fireCustomStatsPixelsIfNeeded() {
        let startDate = repository.customStatsPixelsLastSentTimestamp

        guard customStatsPixelsTrigger.shouldFireCustomStatsPixels(fromDate: startDate),
        let queryData = try? database.fetchAllBrokerProfileQueryData() else { return }

        let endDate = Date.nowMinus(hours: 24)

        let customOptOutStats = customOptOutStatsProvider.customOptOutStats(startDate: startDate,
                                                                            endDate: endDate,
                                                                            andQueryData: queryData)

        fireCustomDataBrokerStatsPixels(customOptOutStats: customOptOutStats)
        fireCustomGlobalStatsPixel(customOptOutStats: customOptOutStats)

        repository.customStatsPixelsLastSentTimestamp = Date.nowMinus(hours: 24)
    }

    /// internal for testing purposes
    func calculateByBroker(_ broker: DataBroker, data: [BrokerProfileQueryData], dateSinceLastSubmission: Date? = nil) -> StatsByBroker {
        let mirrorSitesSize = broker.mirrorSites.filter { !$0.wasRemoved() }.count
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

            numberOfReAppearences += calculateNumberOfProfileReAppereances(query.scanJobData) + mirrorSitesSize
        }

        let numberOfFailureOptOuts = numberOfProfilesFound - numberOfOptOutsInProgress - numberOfSuccessfulOptOuts
        let numberOfNewMatchesFound = calculateNumberOfNewMatchesFound(data)
        let durationOfFirstOptOut = calculateDurationOfFirstOptOut(data, from: dateSinceLastSubmission)

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
            let mirrorSitesCount = key.mirrorSites.filter { !$0.wasRemoved() }.count

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

    /// Calculate the difference in days since the first scan and the first submitted opt-out for the list of brokerProfileQueryData.
    /// The scan and the opt-out do not need to be for the same record.
    /// If an opt-out wasn't submitted yet, we return 0.
    ///
    /// internal for testing purposes
    func calculateDurationOfFirstOptOut(_ brokerProfileQueryData: [BrokerProfileQueryData], from: Date? = nil) -> Int {
        guard let dateOfFirstScan = dateOfFirstScan(brokerProfileQueryData),
              let dateOfFirstSubmittedOptOut = dateOfFirstSubmittedOptOut(brokerProfileQueryData) else {
            return 0
        }

        if dateOfFirstScan > dateOfFirstSubmittedOptOut {
            return 0
        }

        guard let differenceInDays = DataBrokerProtectionPixelsUtilities.numberOfDaysFrom(startDate: dateOfFirstScan, endDate: dateOfFirstSubmittedOptOut) else {
            return 0
        }

        // If the difference in days is in hours, return 1.
        if differenceInDays == 0 {
            return 1
        }

        return differenceInDays
    }
}

private extension DataBrokerProtectionStatsPixels {

    /// Calculates the number of profile reappearances
    /// - Parameter scan: Scan Job Data
    /// - Returns: Count of reappearances
    func calculateNumberOfProfileReAppereances(_ scan: ScanJobData) -> Int {
        return scan.historyEvents.filter { $0.type == .reAppearence }.count
    }

    /// Returns the date of the first scan since the beginning if not from Date is provided
    func dateOfFirstScan(_ brokerProfileQueryData: [BrokerProfileQueryData], from: Date? = nil) -> Date? {
        let allScanOperations = brokerProfileQueryData.map { $0.scanJobData }
        let allScanHistoryEvents = allScanOperations.flatMap { $0.historyEvents }
        let scanStartedEventsSortedByDate = allScanHistoryEvents
            .filter { $0.type == .scanStarted }
            .sorted { $0.date < $1.date }

        if let from = from {
            return scanStartedEventsSortedByDate.filter { from < $0.date }.first?.date
        } else {
            return scanStartedEventsSortedByDate.first?.date
        }
    }

    /// Returns the date of the first sumbitted opt-out. If no from date is provided, we return it from the beginning.
    func dateOfFirstSubmittedOptOut(_ brokerProfileQueryData: [BrokerProfileQueryData], from: Date? = nil) -> Date? {
        let firstOptOutSubmittedEvent = brokerProfileQueryData
            .flatMap { $0.optOutJobData }
            .flatMap { $0.historyEvents }
            .filter { $0.type == .optOutRequested }
            .sorted { $0.date < $1.date }

        if let from = from {
            return firstOptOutSubmittedEvent.filter { from < $0.date }.first?.date
        } else {
            return firstOptOutSubmittedEvent.first?.date
        }
    }

    func shouldFireWeeklyStats(dateOfFirstScan: Date?) -> Bool {
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

    func shouldFireMonthlyStats(dateOfFirstScan: Date?) -> Bool {
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

    func firePixels(for brokerProfileQueryData: [BrokerProfileQueryData], frequency: Frequency, dateSinceLastSubmission: Date? = nil) {
        let statsByBroker = calculateStatsByBroker(brokerProfileQueryData, dateSinceLastSubmission: dateSinceLastSubmission)

        fireGlobalStats(statsByBroker, brokerProfileQueryData: brokerProfileQueryData, frequency: frequency)
        fireStatsByBroker(statsByBroker, frequency: frequency)
    }

    func calculateStatsByBroker(_ brokerProfileQueryData: [BrokerProfileQueryData], dateSinceLastSubmission: Date? = nil) -> [StatsByBroker] {
        let profileQueriesGroupedByBroker = Dictionary(grouping: brokerProfileQueryData, by: { $0.dataBroker })
        let statsByBroker = profileQueriesGroupedByBroker.map { (key: DataBroker, value: [BrokerProfileQueryData]) in
            calculateByBroker(key, data: value, dateSinceLastSubmission: dateSinceLastSubmission)
        }

        return statsByBroker
    }

    func fireGlobalStats(_ stats: [StatsByBroker], brokerProfileQueryData: [BrokerProfileQueryData], frequency: Frequency) {
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

    func fireStatsByBroker(_ stats: [StatsByBroker], frequency: Frequency) {
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

    func fireCustomDataBrokerStatsPixels(customOptOutStats: CustomOptOutStats) {
        Task {
            for stat in customOptOutStats.customIndividualDataBrokerStat {
                handler.fire(pixel(for: stat))
                // Introduce a delay to prevent all databroker pixels from firing at (nearly) the same time
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func pixel(for dataBrokerStat: CustomIndividualDataBrokerStat) -> DataBrokerProtectionPixels {
        .customDataBrokerStatsOptoutSubmit(dataBrokerName: dataBrokerStat.dataBrokerName,
                                           optOutSubmitSuccessRate: dataBrokerStat.optoutSubmitSuccessRate)
    }

    func fireCustomGlobalStatsPixel(customOptOutStats: CustomOptOutStats) {
        handler.fire(pixel(for: customOptOutStats.customAggregateBrokersStat))
    }

    func pixel(for aggregateStat: CustomAggregateBrokersStat) -> DataBrokerProtectionPixels {
        .customGlobalStatsOptoutSubmit(optOutSubmitSuccessRate: aggregateStat.optoutSubmitSuccessRate)
    }
}

// MARK: - Opt out confirmation pixels

extension DataBrokerProtectionStatsPixels {
    // swiftlint:disable:next cyclomatic_complexity
    func fireRegularIntervalConfirmationPixelsForSubmittedOptOuts(for brokerProfileQueryData: [BrokerProfileQueryData]) {
        /*
         This fires pixels to indicate if any submitted opt outs have been confirmed or unconfirmed
         at fixed intervals after the submission (7, 14, and 21 days)
         Goal: Be able to calculate what % of removals occur within x weeks of successful opt-out submission.

         - We get all opt out jobs with status showing they were submitted successfully
         - Compare the date they were submitted successfully with the current date
         - Bucket into >=7, >=14, and >=21 days groups (with overlap between the groups, e.g. it's possible it's been 15 days but neither the 7 day or the 14 day pixel has been fired)
         - Filter those groups based on if the pixel for that time interval has been fired yet
         - Fire the appropriate confirmed/unconfirmed pixels for each job
         - Update the DB to indicate which pixels have been newly fired

         Because submittedSuccessfullyDate will be nil for data that existed before the migration
         the pixels won't fire for old data, which is the behaviour we want.
         */

        let allOptOuts = brokerProfileQueryData.flatMap { $0.optOutJobData }
        let successfullySubmittedOptOuts = allOptOuts.filter { $0.submittedSuccessfullyDate != nil }

        let sevenDayOldPlusOptOutsThatHaveNotFiredPixel = successfullySubmittedOptOuts.filter { optOutJob in
            guard let submittedSuccessfullyDate = optOutJob.submittedSuccessfullyDate else { return false }
            let hasEnoughTimePassedToFirePixel = submittedSuccessfullyDate.hasBeenExceededByNumberOfDays(7)
            return hasEnoughTimePassedToFirePixel && !optOutJob.sevenDaysConfirmationPixelFired
        }

        let fourteenDayOldPlusOptOutsThatHaveNotFiredPixel = successfullySubmittedOptOuts.filter { optOutJob in
            guard let submittedSuccessfullyDate = optOutJob.submittedSuccessfullyDate else { return false }
            let hasEnoughTimePassedToFirePixel = submittedSuccessfullyDate.hasBeenExceededByNumberOfDays(14)
            return hasEnoughTimePassedToFirePixel && !optOutJob.fourteenDaysConfirmationPixelFired
        }

        let twentyOneDayOldPlusOptOutsThatHaveNotFiredPixel = successfullySubmittedOptOuts.filter { optOutJob in
            guard let submittedSuccessfullyDate = optOutJob.submittedSuccessfullyDate else { return false }
            let hasEnoughTimePassedToFirePixel = submittedSuccessfullyDate.hasBeenExceededByNumberOfDays(21)
            return hasEnoughTimePassedToFirePixel && !optOutJob.twentyOneDaysConfirmationPixelFired
        }

        let brokerIDsToNames = brokerProfileQueryData.reduce(into: [Int64: String]()) {
            // Really the ID should never be zero
            $0[$1.dataBroker.id ?? -1] = $1.dataBroker.name
        }

        // Now fire the pixels and update the DB
        for optOutJob in sevenDayOldPlusOptOutsThatHaveNotFiredPixel {
            let brokerName = brokerIDsToNames[optOutJob.brokerId] ?? ""
            let isOptOutConfirmed = optOutJob.extractedProfile.removedDate != nil

            if isOptOutConfirmed {
                handler.fire(.optOutJobAt7DaysConfirmed(dataBroker: brokerName))
            } else {
                handler.fire(.optOutJobAt7DaysUnconfirmed(dataBroker: brokerName))
            }

            guard let extractedProfileID = optOutJob.extractedProfile.id else { continue }
            try? database.updateSevenDaysConfirmationPixelFired(true,
                                                                forBrokerId: optOutJob.brokerId,
                                                                profileQueryId: optOutJob.profileQueryId,
                                                                extractedProfileId: extractedProfileID)
        }

        for optOutJob in fourteenDayOldPlusOptOutsThatHaveNotFiredPixel {
            let brokerName = brokerIDsToNames[optOutJob.brokerId] ?? ""
            let isOptOutConfirmed = optOutJob.extractedProfile.removedDate != nil

            if isOptOutConfirmed {
                handler.fire(.optOutJobAt14DaysConfirmed(dataBroker: brokerName))
            } else {
                handler.fire(.optOutJobAt14DaysUnconfirmed(dataBroker: brokerName))
            }

            guard let extractedProfileID = optOutJob.extractedProfile.id else { continue }
            try? database.updateFourteenDaysConfirmationPixelFired(true,
                                                                   forBrokerId: optOutJob.brokerId,
                                                                   profileQueryId: optOutJob.profileQueryId,
                                                                   extractedProfileId: extractedProfileID)
        }

        for optOutJob in twentyOneDayOldPlusOptOutsThatHaveNotFiredPixel {
            let brokerName = brokerIDsToNames[optOutJob.brokerId] ?? ""
            let isOptOutConfirmed = optOutJob.extractedProfile.removedDate != nil

            if isOptOutConfirmed {
                handler.fire(.optOutJobAt21DaysConfirmed(dataBroker: brokerName))
            } else {
                handler.fire(.optOutJobAt21DaysUnconfirmed(dataBroker: brokerName))
            }

            guard let extractedProfileID = optOutJob.extractedProfile.id else { continue }
            try? database.updateTwentyOneDaysConfirmationPixelFired(true,
                                                                    forBrokerId: optOutJob.brokerId,
                                                                    profileQueryId: optOutJob.profileQueryId,
                                                                    extractedProfileId: extractedProfileID)
        }
    }
}

private extension Date {
    func hasBeenExceededByNumberOfDays(_ days: Int) -> Bool {
        guard let submittedDatePlusTimeInterval = Calendar.current.date(byAdding: .day, value: days, to: self) else {
            return false
        }
        return submittedDatePlusTimeInterval <= Date()
    }
}
