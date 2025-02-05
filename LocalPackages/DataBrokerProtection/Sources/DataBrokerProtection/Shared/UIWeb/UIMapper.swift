//
//  UIMapper.swift
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
import os.log

struct MapperToUI {

    func initialScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIInitialScanState {

        let withoutDeprecated = brokerProfileQueryData.filter { !$0.profileQuery.deprecated }

        let groupedByBroker = Dictionary(grouping: withoutDeprecated, by: { $0.dataBroker.name }).values

        let totalScans = groupedByBroker.reduce(0) { accumulator, brokerQueryData in
            return accumulator + brokerQueryData.totalScans
        }

        let withSortedGroups = groupedByBroker.map { $0.sortedByLastRunDate() }

        let sorted = withSortedGroups.sortedByLastRunDate()

        let partiallyScannedBrokers = sorted.flatMap { brokerQueryGroup in
            brokerQueryGroup.scannedBrokers
        }

        let scanProgress = DBPUIScanProgress(currentScans: partiallyScannedBrokers.completeBrokerScansCount,
                                             totalScans: totalScans,
                                             scannedBrokers: partiallyScannedBrokers)

        let matches = DBPUIDataBrokerProfileMatch.profileMatches(from: withoutDeprecated)

        return .init(resultsFound: matches, scanProgress: scanProgress)
    }

    func maintenanceScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIScanAndOptOutMaintenanceState {
        var inProgressOptOuts = [DBPUIDataBrokerProfileMatch]()
        var removedProfiles = [DBPUIDataBrokerProfileMatch]()

        let scansThatRanAtLeastOnce = brokerProfileQueryData.flatMap { $0.sitesScanned }
        let sitesScanned = Dictionary(grouping: scansThatRanAtLeastOnce, by: { $0 }).count

        // Used to find opt outs on the parent
        let brokerURLsToQueryData =  Dictionary(grouping: brokerProfileQueryData, by: { $0.dataBroker.url })

        brokerProfileQueryData.forEach {
            let dataBroker = $0.dataBroker
            let scanJob = $0.scanJobData
            for optOutJob in $0.optOutJobData {
                let extractedProfile = optOutJob.extractedProfile

                var parentBrokerOptOutJobData: [OptOutJobData]?
                if let parent = $0.dataBroker.parent,
                   let parentsQueryData = brokerURLsToQueryData[parent] {
                    parentBrokerOptOutJobData = parentsQueryData.flatMap { $0.optOutJobData }
                }

                let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOutJob,
                                                               dataBroker: dataBroker,
                                                               parentBrokerOptOutJobData: parentBrokerOptOutJobData,
                                                               optOutUrl: dataBroker.optOutUrl)

                if extractedProfile.removedDate == nil {
                    inProgressOptOuts.append(profileMatch)
                } else {
                    removedProfiles.append(profileMatch)
                }

                if let closestMatchesFoundEvent = scanJob.closestMatchesFoundEvent() {
                    for mirrorSite in dataBroker.mirrorSites where mirrorSite.shouldWeIncludeMirrorSite(for: closestMatchesFoundEvent.date) {
                        let mirrorSiteMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOutJob,
                                                                          dataBrokerName: mirrorSite.name,
                                                                          dataBrokerURL: mirrorSite.url,
                                                                          dataBrokerParentURL: dataBroker.parent,
                                                                          parentBrokerOptOutJobData: parentBrokerOptOutJobData,
                                                                          optOutUrl: dataBroker.optOutUrl)

                        if let extractedProfileRemovedDate = extractedProfile.removedDate,
                           mirrorSite.shouldWeIncludeMirrorSite(for: extractedProfileRemovedDate) {
                            removedProfiles.append(mirrorSiteMatch)
                        } else {
                            inProgressOptOuts.append(mirrorSiteMatch)
                        }
                    }
                }
            }
        }

        let completedOptOutsDictionary = Dictionary(grouping: removedProfiles, by: { $0.dataBroker })
        let completedOptOuts: [DBPUIOptOutMatch] = completedOptOutsDictionary.compactMap { (_, value: [DBPUIDataBrokerProfileMatch]) in
            value.compactMap { match in
                return DBPUIOptOutMatch(profileMatch: match, matches: value.count)
            }
        }.flatMap { $0 }

        let lastScans = getLastScansInformation(brokerProfileQueryData: brokerProfileQueryData)
        let nextScans = getNextScansInformation(brokerProfileQueryData: brokerProfileQueryData)

        return DBPUIScanAndOptOutMaintenanceState(
            inProgressOptOuts: inProgressOptOuts,
            completedOptOuts: completedOptOuts,
            scanSchedule: DBPUIScanSchedule(lastScan: lastScans, nextScan: nextScans),
            scanHistory: DBPUIScanHistory(sitesScanned: sitesScanned)
        )
    }

    private func getLastScansInformation(brokerProfileQueryData: [BrokerProfileQueryData],
                                         currentDate: Date = Date(),
                                         format: String = "dd/MM/yyyy") -> DBPUIScanDate {
        let eightDaysBeforeToday = currentDate.addingTimeInterval(-8 * 24 * 60 * 60)
        let scansInTheLastEightDays = brokerProfileQueryData
            .filter { $0.scanJobData.lastRunDate != nil && $0.scanJobData.lastRunDate! <= currentDate && $0.scanJobData.lastRunDate! > eightDaysBeforeToday }
            .sorted { $0.scanJobData.lastRunDate! < $1.scanJobData.lastRunDate! }
            .reduce(into: [BrokerProfileQueryData]()) { result, element in
                if !result.contains(where: { $0.dataBroker.url == element.dataBroker.url }) {
                    result.append(element)
                }
            }
            .flatMap {
                var brokers = [DBPUIDataBroker]()
                brokers.append(DBPUIDataBroker(name: $0.dataBroker.name,
                                               url: $0.dataBroker.url,
                                               date: $0.scanJobData.lastRunDate!.timeIntervalSince1970,
                                               parentURL: $0.dataBroker.parent,
                                               optOutUrl: $0.dataBroker.optOutUrl))

                for mirrorSite in $0.dataBroker.mirrorSites where mirrorSite.addedAt < $0.scanJobData.lastRunDate! {
                    brokers.append(DBPUIDataBroker(name: mirrorSite.name,
                                                   url: mirrorSite.url,
                                                   date: $0.scanJobData.lastRunDate!.timeIntervalSince1970,
                                                   parentURL: $0.dataBroker.parent,
                                                   optOutUrl: $0.dataBroker.optOutUrl))
                }

                return brokers
            }

        if scansInTheLastEightDays.isEmpty {
            return DBPUIScanDate(date: currentDate.timeIntervalSince1970, dataBrokers: [DBPUIDataBroker]())
        } else {
            return DBPUIScanDate(date: scansInTheLastEightDays.first!.date!, dataBrokers: scansInTheLastEightDays)
        }
    }

    private func getNextScansInformation(brokerProfileQueryData: [BrokerProfileQueryData],
                                         currentDate: Date = Date(),
                                         format: String = "dd/MM/yyyy") -> DBPUIScanDate {
        let eightDaysAfterToday = currentDate.addingTimeInterval(8 * 24 * 60 * 60)
        let scansHappeningInTheNextEightDays = brokerProfileQueryData
            .filter { $0.scanJobData.preferredRunDate != nil && $0.scanJobData.preferredRunDate! > currentDate && $0.scanJobData.preferredRunDate! < eightDaysAfterToday }
            .sorted { $0.scanJobData.preferredRunDate! < $1.scanJobData.preferredRunDate! }
            .reduce(into: [BrokerProfileQueryData]()) { result, element in
                if !result.contains(where: { $0.dataBroker.url == element.dataBroker.url }) {
                    result.append(element)
                }
            }
            .flatMap {
                var brokers = [DBPUIDataBroker]()
                brokers.append(DBPUIDataBroker(name: $0.dataBroker.name,
                                               url: $0.dataBroker.url,
                                               date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970,
                                               parentURL: $0.dataBroker.parent,
                                               optOutUrl: $0.dataBroker.optOutUrl))

                for mirrorSite in $0.dataBroker.mirrorSites {
                    if let removedDate = mirrorSite.removedAt {
                        if removedDate > $0.scanJobData.preferredRunDate! {
                            brokers.append(DBPUIDataBroker(name: mirrorSite.name,
                                                           url: mirrorSite.url,
                                                           date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970,
                                                           parentURL: $0.dataBroker.parent,
                                                           optOutUrl: $0.dataBroker.optOutUrl))
                        }
                    } else {
                        brokers.append(DBPUIDataBroker(name: mirrorSite.name,
                                                       url: mirrorSite.url,
                                                       date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970,
                                                       parentURL: $0.dataBroker.parent,
                                                       optOutUrl: $0.dataBroker.optOutUrl))
                    }
                }

                return brokers
            }

        if scansHappeningInTheNextEightDays.isEmpty {
            return DBPUIScanDate(date: currentDate.timeIntervalSince1970, dataBrokers: [DBPUIDataBroker]())
        } else {
            return DBPUIScanDate(date: scansHappeningInTheNextEightDays.first!.date!, dataBrokers: scansHappeningInTheNextEightDays)
        }
    }

    func mapToUIDebugMetadata(metadata: DBPBackgroundAgentMetadata?, brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIDebugMetadata {
        let currentAppVersion = Bundle.main.fullVersionNumber ?? "ERROR: Error fetching app version"

        guard let metadata = metadata else {
            return DBPUIDebugMetadata(lastRunAppVersion: currentAppVersion, isAgentRunning: false)
        }

        let lastOperation = brokerProfileQueryData.lastOperation
        let lastStartedOperation = brokerProfileQueryData.lastStartedOperation
        let lastError = brokerProfileQueryData.lastOperationThatErrored

        let lastOperationBrokerURL = brokerProfileQueryData.filter { $0.dataBroker.id == lastOperation?.brokerId }.first?.dataBroker.url
        let lastStartedOperationBrokerURL = brokerProfileQueryData.filter { $0.dataBroker.id == lastStartedOperation?.brokerId }.first?.dataBroker.url

        let metadataUI = DBPUIDebugMetadata(lastRunAppVersion: currentAppVersion,
                                            lastRunAgentVersion: metadata.backgroundAgentVersion,
                                            isAgentRunning: true,
                                            lastSchedulerOperationType: lastOperation?.toString,
                                            lastSchedulerOperationTimestamp: lastOperation?.lastRunDate?.timeIntervalSince1970.withoutDecimals,
                                            lastSchedulerOperationBrokerUrl: lastOperationBrokerURL,
                                            lastSchedulerErrorMessage: lastError?.error,
                                            lastSchedulerErrorTimestamp: lastError?.date.timeIntervalSince1970.withoutDecimals,
                                            lastSchedulerSessionStartTimestamp: metadata.lastSchedulerSessionStartTimestamp,
                                            agentSchedulerState: metadata.agentSchedulerState,
                                            lastStartedSchedulerOperationType: lastStartedOperation?.toString,
                                            lastStartedSchedulerOperationTimestamp: lastStartedOperation?.historyEvents.closestHistoryEvent?.date.timeIntervalSince1970.withoutDecimals,
                                            lastStartedSchedulerOperationBrokerUrl: lastStartedOperationBrokerURL)

#if DEBUG
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(metadataUI)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Logger.dataBrokerProtection.log("Metadata: \(jsonString, privacy: .public)")
            }
        } catch {
            Logger.dataBrokerProtection.error("Error encoding struct to JSON: \(error.localizedDescription, privacy: .public)")
        }
#endif

        return metadataUI
    }
}

extension Bundle {
    var fullVersionNumber: String? {
        guard let appVersion = self.releaseVersionNumber,
              let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return nil
        }

        return appVersion + " (build: \(buildNumber))"
    }
}

extension TimeInterval {
    var withoutDecimals: Double {
        Double(Int(self))
    }
}

extension Date {

    func toFormat(_ format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}

extension String {

    func toDate(using format: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format

        if let date = dateFormatter.date(from: self) {
            return date
        } else {
            fatalError("String should be on the correct date format")
        }
    }
}

fileprivate extension BrokerProfileQueryData {

    var closestHistoryEvent: HistoryEvent? {
        events.sorted(by: { $0.date > $1.date }).first
    }

    var sitesScanned: [String] {
        if scanJobData.lastRunDate != nil {
            let scanEvents = scanJobData.scanStartedEvents()
            var sitesScanned = [dataBroker.name]

            for mirrorSite in dataBroker.mirrorSites {
                let wasMirrorSiteScanned = scanEvents.contains { event in
                    mirrorSite.shouldWeIncludeMirrorSite(for: event.date)
                }

                if wasMirrorSiteScanned {
                    sitesScanned.append(mirrorSite.name)
                }
            }

            return sitesScanned
        }

        return [String]()
    }
}

/// Extension on `Optional` which provides comparison abilities when the wrapped type is `Date`
private extension Optional where Wrapped == Date {

    static func < (lhs: Date?, rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (lhsDate?, rhsDate?):
            return lhsDate < rhsDate
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (nil, nil):
            return false
        }
    }

    static func == (lhs: Date?, rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs == rhs
        case (nil, nil):
            return true
        default:
            return false
        }
    }
}

private extension Array where Element == [BrokerProfileQueryData] {

    /// Sorts the 2-dimensional array in ascending order based on the `lastRunDate` value of the first element of each internal array
    ///
    /// - Returns: An array of `[BrokerProfileQueryData]` values sorted by the first `lastRunDate` of each element
    func sortedByLastRunDate() -> Self {
        self.sorted { lhs, rhs in
            let lhsDate = lhs.first?.scanJobData.lastRunDate
            let rhsDate = rhs.first?.scanJobData.lastRunDate

            if lhsDate == rhsDate {
                return lhs.first?.dataBroker.name ?? "" < rhs.first?.dataBroker.name ?? ""
            } else {
                return lhsDate < rhsDate
            }
        }
    }
}

fileprivate extension Array where Element == BrokerProfileQueryData {

    typealias ScannedBroker = DBPUIScanProgress.ScannedBroker

    var totalScans: Int {
        guard let broker = self.first?.dataBroker else { return 0 }
        return 1 + broker.mirrorSites.filter { $0.shouldWeIncludeMirrorSite() }.count
    }

    /// Returns an array of brokers which have been either fully or partially scanned
    ///
    /// A broker is considered fully scanned is all scan jobs for that broker have completed.
    /// A broker is considered partially scanned if at least one scan job for that broker has completed
    /// Mirror brokers will be included in the returned array when `MirrorSite.shouldWeIncludeMirrorSite` returns true
    var scannedBrokers: [ScannedBroker] {
        guard let broker = self.first?.dataBroker else { return [] }

        var completedScans = 0
        self.forEach {
            completedScans += $0.scanJobData.lastRunDate == nil ? 0 : 1
        }

        guard completedScans != 0 else { return [] }

        var status: ScannedBroker.Status = .inProgress
        if completedScans == self.count {
            status = .completed
        }

        let mirrorBrokers = broker.mirrorSites.compactMap {
            $0.shouldWeIncludeMirrorSite() ? $0.scannedBroker(withStatus: status) : nil
        }

        return [ScannedBroker(name: broker.name, url: broker.url, status: status)] + mirrorBrokers
    }

    var lastOperation: BrokerJobData? {
        let allOperations = flatMap { $0.operationsData }
        let lastOperation = allOperations.sorted(by: {
            if let date1 = $0.lastRunDate, let date2 = $1.lastRunDate {
                return date1 > date2
            } else if $0.lastRunDate != nil {
                return true
            } else {
                return false
            }
        }).first

        return lastOperation
    }

    var lastOperationThatErrored: HistoryEvent? {
        let lastError = flatMap { $0.operationsData }
            .flatMap { $0.historyEvents }
            .filter { $0.isError }
            .sorted(by: { $0.date > $1.date })
            .first

        return lastError
    }

    var lastStartedOperation: BrokerJobData? {
        let allOperations = flatMap { $0.operationsData }

        return allOperations.sorted(by: {
            if let date1 = $0.historyEvents.closestHistoryEvent?.date, let date2 = $1.historyEvents.closestHistoryEvent?.date {
                return date1 > date2
            } else if $0.historyEvents.closestHistoryEvent?.date != nil {
                return true
            } else {
                return false
            }
        }).first
    }

    /// Sorts the array in ascending order based on `lastRunDate`
    ///
    /// - Returns: An array of `BrokerProfileQueryData` sorted by `lastRunDate`
    func sortedByLastRunDate() -> Self {
        self.sorted { lhs, rhs in
            lhs.scanJobData.lastRunDate < rhs.scanJobData.lastRunDate
        }
    }
}

extension Array where Element == DBPUIScanProgress.ScannedBroker {
    var completeBrokerScansCount: Int {
        reduce(0) { accumulator, scannedBrokers in
            scannedBrokers.status == .completed ? accumulator + 1 : accumulator
        }
    }
}

fileprivate extension BrokerJobData {
    var toString: String {
        if (self as? OptOutJobData) != nil {
            return "optOut"
        } else {
            return "scan"
        }
    }
}

fileprivate extension Array where Element == HistoryEvent {
    var closestHistoryEvent: HistoryEvent? {
        self.sorted(by: { $0.date > $1.date }).first
    }
}

extension HistoryEvent {

    var isError: Bool {
        switch type {
        case .error:
            return true
        default:
            return false
        }
    }

    var error: String? {
        switch type {
        case .error(let error):
            return error.name
        default: return nil
        }
    }
}
