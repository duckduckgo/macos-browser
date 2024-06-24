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

struct MapperToUI {

    func mapToUI(_ dataBroker: DataBroker, extractedProfile: ExtractedProfile) -> DBPUIDataBrokerProfileMatch {
        DBPUIDataBrokerProfileMatch(
            dataBroker: mapToUI(dataBroker),
            name: extractedProfile.fullName ?? "No name",
            addresses: extractedProfile.addresses?.map(mapToUI) ?? [],
            alternativeNames: extractedProfile.alternativeNames ?? [String](),
            relatives: extractedProfile.relatives ?? [String](),
            date: extractedProfile.removedDate?.timeIntervalSince1970
        )
    }

    func mapToUI(_ dataBrokerName: String, databrokerURL: String, extractedProfile: ExtractedProfile) -> DBPUIDataBrokerProfileMatch {
        DBPUIDataBrokerProfileMatch(
            dataBroker: DBPUIDataBroker(name: dataBrokerName, url: databrokerURL),
            name: extractedProfile.fullName ?? "No name",
            addresses: extractedProfile.addresses?.map(mapToUI) ?? [],
            alternativeNames: extractedProfile.alternativeNames ?? [String](),
            relatives: extractedProfile.relatives ?? [String](),
            date: extractedProfile.removedDate?.timeIntervalSince1970
        )
    }

    func mapToUI(_ dataBroker: DataBroker) -> DBPUIDataBroker {
        DBPUIDataBroker(name: dataBroker.name, url: dataBroker.url)
    }

    func mapToUI(_ address: AddressCityState) -> DBPUIUserProfileAddress {
        DBPUIUserProfileAddress(street: address.fullAddress, city: address.city, state: address.state, zipCode: nil)
    }

    func initialScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIInitialScanState {
        // Total and current scans are misleading. The UI are counting this per broker and
        // not by the total real cans that the app is doing.
        let profileQueriesGroupedByBroker = Dictionary(grouping: brokerProfileQueryData, by: { $0.dataBroker.name })

        // We don't want to consider deprecated queries when reporting manual scans to the UI
        let filteredProfileQueriesGroupedByBroker = profileQueriesGroupedByBroker.mapValues { queries in
            queries.filter { !$0.profileQuery.deprecated }
        }

        let totalScans = filteredProfileQueriesGroupedByBroker.reduce(0) { accumulator, element in
            return accumulator + element.value.totalScans
        }

        let (completedScans, scannedBrokers): (Int, [DBPUIScanProgress.ScannedBroker]) = filteredProfileQueriesGroupedByBroker.reduce((0, [])) { accumulator, element in

            let scannedBrokers = element.value.scannedBrokers
            guard scannedBrokers.count != 0 else { return accumulator }

            var (completedScans, brokers) = accumulator

            completedScans += scannedBrokers.count

            brokers.append(contentsOf: scannedBrokers)

            return (completedScans, brokers)
        }

        let scanProgress = DBPUIScanProgress(currentScans: completedScans, totalScans: totalScans, scannedBrokers: scannedBrokers)
        let matches = mapMatchesToUI(brokerProfileQueryData)

        return .init(resultsFound: matches, scanProgress: scanProgress)
    }

    private func mapMatchesToUI(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> [DBPUIDataBrokerProfileMatch] {
        return brokerProfileQueryData.flatMap {
            var profiles = [DBPUIDataBrokerProfileMatch]()
            for extractedProfile in $0.extractedProfiles where !$0.profileQuery.deprecated {
                profiles.append(mapToUI($0.dataBroker, extractedProfile: extractedProfile))

                if !$0.dataBroker.mirrorSites.isEmpty {
                    let mirrorSitesMatches = $0.dataBroker.mirrorSites.compactMap { mirrorSite in
                        if mirrorSite.shouldWeIncludeMirrorSite() {
                            return mapToUI(mirrorSite.name, databrokerURL: mirrorSite.url, extractedProfile: extractedProfile)
                        }

                        return nil
                    }
                    profiles.append(contentsOf: mirrorSitesMatches)
                }
            }

            return profiles
        }
    }

    func maintenanceScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIScanAndOptOutMaintenanceState {
        var inProgressOptOuts = [DBPUIDataBrokerProfileMatch]()
        var removedProfiles = [DBPUIDataBrokerProfileMatch]()

        let scansThatRanAtLeastOnce = brokerProfileQueryData.flatMap { $0.sitesScanned }
        let sitesScanned = Dictionary(grouping: scansThatRanAtLeastOnce, by: { $0 }).count

        brokerProfileQueryData.forEach {
            let dataBroker = $0.dataBroker
            let scanJob = $0.scanJobData
            for optOutJob in $0.optOutJobData {
                let extractedProfile = optOutJob.extractedProfile
                let profileMatch = mapToUI(dataBroker, extractedProfile: extractedProfile)

                if extractedProfile.removedDate == nil {
                    inProgressOptOuts.append(profileMatch)
                } else {
                    removedProfiles.append(profileMatch)
                }

                if let closestMatchesFoundEvent = scanJob.closestMatchesFoundEvent() {
                    for mirrorSite in dataBroker.mirrorSites where mirrorSite.shouldWeIncludeMirrorSite(for: closestMatchesFoundEvent.date) {
                        let mirrorSiteMatch = mapToUI(mirrorSite.name, databrokerURL: mirrorSite.url, extractedProfile: extractedProfile)

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
        let completedOptOuts: [DBPUIOptOutMatch] = completedOptOutsDictionary.compactMap { (key: DBPUIDataBroker, value: [DBPUIDataBrokerProfileMatch]) in
            value.compactMap { match in
                guard let removedDate = match.date else { return nil }
                return DBPUIOptOutMatch(dataBroker: key,
                                        matches: value.count,
                                        name: match.name,
                                        alternativeNames: match.alternativeNames,
                                        addresses: match.addresses,
                                        date: removedDate)
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
                brokers.append(DBPUIDataBroker(name: $0.dataBroker.name, url: $0.dataBroker.url, date: $0.scanJobData.lastRunDate!.timeIntervalSince1970))

                for mirrorSite in $0.dataBroker.mirrorSites where mirrorSite.addedAt < $0.scanJobData.lastRunDate! {
                    brokers.append(DBPUIDataBroker(name: mirrorSite.name, url: mirrorSite.url, date: $0.scanJobData.lastRunDate!.timeIntervalSince1970))
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
                brokers.append(DBPUIDataBroker(name: $0.dataBroker.name, url: $0.dataBroker.url, date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970))

                for mirrorSite in $0.dataBroker.mirrorSites {
                    if let removedDate = mirrorSite.removedAt {
                        if removedDate > $0.scanJobData.preferredRunDate! {
                            brokers.append(DBPUIDataBroker(name: mirrorSite.name, url: mirrorSite.url, date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970))
                        }
                    } else {
                        brokers.append(DBPUIDataBroker(name: mirrorSite.name, url: mirrorSite.url, date: $0.scanJobData.preferredRunDate!.timeIntervalSince1970))
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
                os_log("Metadata: %{public}s", log: OSLog.default, type: .info, jsonString)
            }
        } catch {
            os_log("Error encoding struct to JSON: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
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

fileprivate extension Array where Element == BrokerProfileQueryData {

    var totalScans: Int {
        guard let broker = self.first?.dataBroker else { return 0 }
        return 1 + broker.mirrorSites.filter { $0.shouldWeIncludeMirrorSite() }.count
    }
    
    /// Returns an array of brokers which have been scanned
    ///
    /// Note 1: A Broker is considered scanned if all scan jobs for that broker have been run.
    /// Note 2: Mirror brokers will be included in the returned array when `MirrorSite.shouldWeIncludeMirrorSite` returns true
    var scannedBrokers: [DBPUIScanProgress.ScannedBroker] {
        guard let broker = self.first?.dataBroker,
                self.allSatisfy({ $0.scanJobData.lastRunDate != nil }) else { return [] }

        let mirrorBrokers: [DBPUIScanProgress.ScannedBroker] = broker.mirrorSites.compactMap {
            guard $0.shouldWeIncludeMirrorSite() else { return nil }
            return DBPUIScanProgress.ScannedBroker(name: $0.name, url: $0.url)
        }
        return [DBPUIScanProgress.ScannedBroker(name: broker.name, url: broker.url)] + mirrorBrokers
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

fileprivate extension MirrorSite {

    func shouldWeIncludeMirrorSite(for date: Date = Date()) -> Bool {
        if let removedAt = self.removedAt {
            return self.addedAt < date && date < removedAt
        } else {
            return self.addedAt < date
        }
    }
}
