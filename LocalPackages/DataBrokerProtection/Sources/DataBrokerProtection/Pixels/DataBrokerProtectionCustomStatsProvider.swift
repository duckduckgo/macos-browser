//
//  DataBrokerProtectionCustomStatsProvider.swift
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

/// Type encapsulating custom data broker and global stats
struct CustomStats: Equatable {
    let customDataBrokerStats: [CustomDataBrokerStat]
    let customGlobalStat: CustomGlobalStat
}

/// Encapsulates data broker stats
struct CustomDataBrokerStat: Equatable {
    let dataBrokerName: String
    let optoutSubmitSuccessRate: Double
}

/// Encapsulates global (i.e across all data broker) stats
struct CustomGlobalStat: Equatable {
    let optoutSubmitSuccessRate: Double
}

// Conforming types provide a method to calculate `CustomStats`
protocol DataBrokerProtectionCustomStatsProvider {

    /// This method calculates custom statistics for data brokers based on the provided query data within a specified date range.
    /// - Parameters:
    ///   - startDate: An optional start date to filter matches and requests. If nil, the filtering starts from the earliest date available.
    ///   - endDate: The end date to filter matches and requests. All matches and requests are considered up to this date.
    ///   - queryData: An array of BrokerProfileQueryData objects containing data broker query information, scan job data, and opt-out job data.
    /// - Returns: A CustomStats object containing the statistics for each data broker and the global statistics.
    func customStats(startDate: Date?,
                     endDate: Date,
                     andQueryData queryData: [BrokerProfileQueryData]) -> CustomStats
}

struct DefaultDataBrokerProtectionCustomStatsProvider: DataBrokerProtectionCustomStatsProvider {

    func customStats(startDate: Date?,
                     endDate: Date,
                     andQueryData queryData: [BrokerProfileQueryData]) -> CustomStats {

        var customDataBrokerStats: [CustomDataBrokerStat] = []
        var totalGlobalMatches: Int = 0
        var totalGlobalRequests: Int = 0

        // Group by broker
        let groupedByBroker = Dictionary(grouping: queryData) { $0.dataBroker.id }

        // Loop over each group
        for (dataBroker, brokerQueryData) in groupedByBroker {

            // Get matches within start - end dates
            let matchesBetweenDates = matchesBetween(startDate: startDate, endDate: endDate, queryData: brokerQueryData)

            let totalMatches = matchesBetweenDates.count

            // If this data broker has no associated matches, skip to the next data broker
            guard totalMatches != 0 else { continue }

            totalGlobalMatches += totalMatches

            // Get opt-outs since start date
            let requestsSinceStartDate = requestsSince(startDate: startDate, queryData: brokerQueryData)

            // Calculate number of opt-out requests
            let totalOptOutRequests = matchingOptOutCount(matches: matchesBetweenDates, optOuts: requestsSinceStartDate)

            totalGlobalRequests += totalOptOutRequests

            // Calculate opt-out success rate
            let optOutSuccessRate = totalMatches > 0 ? Double(totalOptOutRequests) / Double(totalMatches) : 0
            let roundedOptOutSuccessRate = (optOutSuccessRate * 100).rounded() / 100

            let dataBrokerName = groupedByBroker[dataBroker]?.first?.dataBroker.name ?? ""

            let customDataBrokerStat = CustomDataBrokerStat(dataBrokerName: dataBrokerName,
                                                             optoutSubmitSuccessRate: roundedOptOutSuccessRate)

            customDataBrokerStats.append(customDataBrokerStat)

        }

        let globalSuccessRate = totalGlobalMatches > 0 ? Double(totalGlobalRequests) / Double(totalGlobalMatches) : 0
        let roundedGlobalSuccessRate = (globalSuccessRate * 100).rounded() / 100
        let globalStats = CustomGlobalStat(optoutSubmitSuccessRate: roundedGlobalSuccessRate)
        return CustomStats(customDataBrokerStats: customDataBrokerStats, customGlobalStat: globalStats)
    }
}

private extension DefaultDataBrokerProtectionCustomStatsProvider {

    func matchesBetween(startDate: Date?, endDate: Date, queryData: [BrokerProfileQueryData]) -> [HistoryEvent] {
        let allMatches = queryData.flatMap { $0.scanJobData.matchEvents }
        let betweenDatesMatches = allMatches.filter { match in
            if let startDate = startDate {
                return match.date >= startDate && match.date <= endDate
            } else {
                return match.date <= endDate
            }
        }
        return betweenDatesMatches
    }

    func requestsSince(startDate: Date?, queryData: [BrokerProfileQueryData]) -> [HistoryEvent] {
        let allOptOutRequests = queryData.flatMap { $0.optOutJobData.flatMap { $0.optOutRequestedEvents } }
        let requestsSinceStartDate: [HistoryEvent]
        if let startDate = startDate {
            requestsSinceStartDate = allOptOutRequests.filter { $0.date >= startDate }
        } else {
            requestsSinceStartDate = allOptOutRequests
        }
        return requestsSinceStartDate
    }

    func matchingOptOutCount(matches: [HistoryEvent], optOuts: [HistoryEvent]) -> Int {
        let totalOptOutRequests = matches.reduce(0) { count, match in
            let optOutRequested = optOuts.contains {
                let matchDatePlus24 = Calendar.current.date(byAdding: .hour, value: 24, to: match.date) ?? Date()
                return $0.profileQueryId == match.profileQueryId &&
                $0.brokerId == match.brokerId &&
                ($0.date < matchDatePlus24 && $0.date > match.date)
            }
            return count + (optOutRequested ? 1 : 0)
        }
        return totalOptOutRequests
    }
}
