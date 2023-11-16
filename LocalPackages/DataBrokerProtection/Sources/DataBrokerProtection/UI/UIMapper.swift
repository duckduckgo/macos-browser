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

struct MapperToUI {

    func mapToUI(_ dataBroker: DataBroker, extractedProfile: ExtractedProfile) -> DBPUIDataBrokerProfileMatch {
        DBPUIDataBrokerProfileMatch(
            dataBroker: mapToUI(dataBroker),
            name: extractedProfile.fullName ?? "No name",
            addresses: extractedProfile.addresses?.map(mapToUI) ?? [],
            alternativeNames: extractedProfile.alternativeNames ?? [String](),
            relatives: extractedProfile.relatives ?? [String]()
        )
    }

    func mapToUI(_ dataBrokerName: String, extractedProfile: ExtractedProfile) -> DBPUIDataBrokerProfileMatch {
        DBPUIDataBrokerProfileMatch(
            dataBroker: DBPUIDataBroker(name: dataBrokerName),
            name: extractedProfile.fullName ?? "No name",
            addresses: extractedProfile.addresses?.map(mapToUI) ?? [],
            alternativeNames: extractedProfile.alternativeNames ?? [String](),
            relatives: extractedProfile.relatives ?? [String]()
        )
    }

    func mapToUI(_ dataBroker: DataBroker) -> DBPUIDataBroker {
        DBPUIDataBroker(name: dataBroker.name)
    }

    func mapToUI(_ address: AddressCityState) -> DBPUIUserProfileAddress {
        DBPUIUserProfileAddress(street: address.fullAddress, city: address.city, state: address.state, zipCode: nil)
    }

    func initialScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIInitialScanState {
        let totalScans = brokerProfileQueryData.reduce(0) { accumulator, element in
            return accumulator + element.totalScans
        }
        let currentScans = brokerProfileQueryData.reduce(0) { accumulator, element in
            return accumulator + element.currentScans
        }
        let scanProgress = DBPUIScanProgress(currentScans: currentScans, totalScans: totalScans)
        let matches = mapMatchesToUI(brokerProfileQueryData)

        return .init(resultsFound: matches, scanProgress: scanProgress)
    }

    private func mapMatchesToUI(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> [DBPUIDataBrokerProfileMatch] {
        let matches = brokerProfileQueryData.compactMap {
            for extractedProfile in $0.extractedProfiles {
                var profiles = [mapToUI($0.dataBroker, extractedProfile: extractedProfile)]
                if !$0.dataBroker.mirrorSites.isEmpty {
                    let mirrorSitesMatches = $0.dataBroker.mirrorSites.compactMap { mirrorSite in
                        if mirrorSite.shouldWeIncludeMirrorSite() {
                            return mapToUI(mirrorSite.name, extractedProfile: extractedProfile)
                        }

                        return nil
                    }
                    profiles.append(contentsOf: mirrorSitesMatches)
                }

                return profiles
            }

            return nil
        }

        return matches.flatMap { $0 }
    }

    func maintenanceScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIScanAndOptOutMaintenanceState {
        var inProgressOptOuts = [DBPUIDataBrokerProfileMatch]()
        var removedProfiles = [DBPUIDataBrokerProfileMatch]()

        let scansThatRanAtLeastOnce = brokerProfileQueryData.flatMap { $0.sitesScanned }
        let sitesScanned = Dictionary.init(grouping: scansThatRanAtLeastOnce, by: { $0 }).count

        brokerProfileQueryData.forEach {
            let dataBroker = $0.dataBroker
            let scanOperation = $0.scanOperationData
            for optOutOperation in $0.optOutOperationsData {
                let extractedProfile = optOutOperation.extractedProfile
                let profileMatch = mapToUI(dataBroker, extractedProfile: extractedProfile)

                if extractedProfile.removedDate == nil {
                    inProgressOptOuts.append(profileMatch)
                } else {
                    removedProfiles.append(profileMatch)
                }

                if let closestMatchesFoundEvent = scanOperation.closestMatchesFoundEvent() {
                    for mirrorSite in dataBroker.mirrorSites where mirrorSite.shouldWeIncludeMirrorSite(for: closestMatchesFoundEvent.date) {
                        let mirrorSiteMatch = mapToUI(mirrorSite.name, extractedProfile: extractedProfile)

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

        let completedOptOutsDictionary = Dictionary.init(grouping: removedProfiles, by: { $0.dataBroker })
        let completedOptOuts = completedOptOutsDictionary.map { (key: DBPUIDataBroker, value: [DBPUIDataBrokerProfileMatch]) in
            DBPUIOptOutMatch(dataBroker: key, matches: value.count)
        }
        let lastScans = getLastScanInformation(brokerProfileQueryData: brokerProfileQueryData)
        let nextScans = getNextScansInformation(brokerProfileQueryData: brokerProfileQueryData)

        return DBPUIScanAndOptOutMaintenanceState(
            inProgressOptOuts: inProgressOptOuts,
            completedOptOuts: completedOptOuts,
            scanSchedule: DBPUIScanSchedule(lastScan: lastScans, nextScan: nextScans),
            scanHistory: DBPUIScanHistory(sitesScanned: sitesScanned)
        )
    }

    private func getLastScanInformation(brokerProfileQueryData: [BrokerProfileQueryData],
                                        currentDate: Date = Date(),
                                        format: String = "dd/MM/yyyy") -> DBUIScanDate {
        let scansGroupedByLastRunDate = Dictionary.init(grouping: brokerProfileQueryData, by: { $0.scanOperationData.lastRunDate?.toFormat(format) })
        let closestScansBeforeToday = scansGroupedByLastRunDate
            .filter { $0.key != nil && $0.key!.toDate(using: format) < currentDate }
            .sorted { $0.key! < $1.key! }
            .flatMap { [$0.key?.toDate(using: format): $0.value] }
            .last

        return scanDate(element: closestScansBeforeToday)
    }

    private func getNextScansInformation(brokerProfileQueryData: [BrokerProfileQueryData],
                                         currentDate: Date = Date(),
                                         format: String = "dd/MM/yyyy") -> DBUIScanDate {
        let scansGroupedByPreferredRunDate = Dictionary.init(grouping: brokerProfileQueryData, by: { $0.scanOperationData.preferredRunDate?.toFormat(format) })
        let closestScansAfterToday = scansGroupedByPreferredRunDate
            .filter { $0.key != nil && $0.key!.toDate(using: format) > currentDate }
            .sorted { $0.key! < $1.key! }
            .flatMap { [$0.key?.toDate(using: format): $0.value] }
            .first

        return scanDate(element: closestScansAfterToday)
    }

    private func scanDate(element: Dictionary<Date?, [BrokerProfileQueryData]>.Element?) -> DBUIScanDate {
        if let element = element, let date = element.key {
            return DBUIScanDate(
                date: date.timeIntervalSince1970,
                dataBrokers: element.value.flatMap {
                    var brokers = [DBPUIDataBroker(name: $0.dataBroker.name)]

                    for mirrorSite in $0.dataBroker.mirrorSites where mirrorSite.shouldWeIncludeMirrorSite(for: date) {
                        brokers.append(DBPUIDataBroker(name: mirrorSite.name))
                    }

                    return brokers
                }
            )
        } else {
            return DBUIScanDate(date: 0, dataBrokers: [DBPUIDataBroker]())
        }
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

    var totalScans: Int {
        return 1 + dataBroker.mirrorSites.filter { $0.shouldWeIncludeMirrorSite() }.count
    }

    var currentScans: Int {
        if scanOperationData.lastRunDate != nil {
            return 1 + dataBroker.mirrorSites.filter { $0.shouldWeIncludeMirrorSite() }.count
        } else {
            return 0
        }
    }

    var sitesScanned: [String] {
        if scanOperationData.lastRunDate != nil {
            let scanEvents = scanOperationData.scanStartedEvents()
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

fileprivate extension MirrorSite {

    func shouldWeIncludeMirrorSite(for date: Date = Date()) -> Bool {
        if let removedAt = self.removedAt {
            return self.addedAt < date && date < removedAt
        } else {
            return self.addedAt < date
        }
    }
}
