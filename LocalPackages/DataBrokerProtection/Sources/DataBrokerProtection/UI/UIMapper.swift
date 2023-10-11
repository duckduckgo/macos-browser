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

    func mapToUI(_ dataBroker: DataBroker) -> DBPUIDataBroker {
        DBPUIDataBroker(name: dataBroker.name)
    }

    func mapToUI(_ address: AddressCityState) -> DBPUIUserProfileAddress {
        DBPUIUserProfileAddress(street: address.fullAddress, city: address.city, state: address.state, zipCode: nil)
    }

    func initialScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIInitialScanState {
        /// In the future we need to take into account mirror sites when counting for the total scans
        /// Tech design: https://app.asana.com/0/481882893211075/1205594901067225/f
        let totalScans = brokerProfileQueryData.count
        let currentScans = brokerProfileQueryData.filter { $0.scanOperationData.lastRunDate != nil }.count
        let scanProgress = DBPUIScanProgress(currentScans: currentScans, totalScans: totalScans)
        let matches = brokerProfileQueryData.compactMap {
            for extractedProfile in $0.extractedProfiles {
                return mapToUI($0.dataBroker, extractedProfile: extractedProfile)
            }

            return nil
        }

        return .init(resultsFound: matches, scanProgress: scanProgress)
    }

    func maintenanceScanState(_ brokerProfileQueryData: [BrokerProfileQueryData]) -> DBPUIScanAndOptOutMaintenanceState {
        var inProgressOptOuts = [DBPUIDataBrokerProfileMatch]()
        var removedProfiles = [DBPUIDataBrokerProfileMatch]()

        let scansThatRanAtLeastOnce = brokerProfileQueryData.filter { $0.scanOperationData.lastRunDate != nil }
        let sitesScanned = Dictionary.init(grouping: scansThatRanAtLeastOnce, by: { $0.dataBroker.name }).count
        let scansCompleted = brokerProfileQueryData.reduce(0) { result, queryData in
            return result + queryData.scanOperationData.historyEvents.filter { $0.type == .scanStarted }.count
        }

        brokerProfileQueryData.forEach {
            for extractedProfile in $0.extractedProfiles {
                let profileMatch = mapToUI($0.dataBroker, extractedProfile: extractedProfile)
                if extractedProfile.removedDate == nil {
                    inProgressOptOuts.append(profileMatch)
                } else {
                    removedProfiles.append(profileMatch)
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
            scanHistory: DBPUIScanHistory(sitesScanned: sitesScanned, scansCompleted: scansCompleted)
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
                date: date,
                dataBrokers: element.value.map { DBPUIDataBroker(name: $0.dataBroker.name)}
            )
        } else {
            return DBUIScanDate(date: Date(), dataBrokers: [DBPUIDataBroker]())
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
