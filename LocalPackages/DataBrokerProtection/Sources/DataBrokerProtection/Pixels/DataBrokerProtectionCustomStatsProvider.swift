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
struct CustomOptOutStats: Equatable {
    let customIndividualDataBrokerStat: [CustomIndividualDataBrokerStat]
    let customAggregateBrokersStat: CustomAggregateBrokersStat
}

/// Encapsulates data broker stats
struct CustomIndividualDataBrokerStat: Equatable {
    let dataBrokerName: String
    let optoutSubmitSuccessRate: Double
}

/// Encapsulates aggregate (i.e across all data broker) stats
struct CustomAggregateBrokersStat: Equatable {
    let optoutSubmitSuccessRate: Double
}

// Conforming types provide a method to calculate `CustomOptOutStats`
protocol DataBrokerProtectionCustomOptOutStatsProvider {

    /// This method calculates custom statistics for data brokers based on the provided query data within a specified date range.
    /// - Parameters:
    ///   - startDate: An optional start date to filter optout creation and request events. If nil, the filtering starts from the earliest date available.
    ///   - endDate: The end date to filter optout creation events. All optout creation events considered up to this date.
    ///   - queryData: An array of BrokerProfileQueryData objects containing data broker query information, scan job data, and opt-out job data.
    /// - Returns: A CustomStats object containing the statistics for each data broker and the global statistics.
    func customOptOutStats(startDate: Date?,
                           endDate: Date,
                           andQueryData queryData: [BrokerProfileQueryData]) -> CustomOptOutStats
}

struct DefaultDataBrokerProtectionCustomOptOutStatsProvider: DataBrokerProtectionCustomOptOutStatsProvider {

    func customOptOutStats(startDate: Date?,
                           endDate: Date,
                           andQueryData queryData: [BrokerProfileQueryData]) -> CustomOptOutStats {

        var customIndividualDataBrokerStats: [CustomIndividualDataBrokerStat] = []
        var totalGlobalOptOuts: Int = 0
        var totalGlobalRequests: Int = 0

        // Group by broker
        let groupedByBroker = Dictionary(grouping: queryData) { $0.dataBroker.id }

        // Loop over each group
        for (dataBroker, brokerQueryData) in groupedByBroker {

            // Get opt-out jobs between start - end dates
            let optOutJobs = optOutJobsBetween(startDate: startDate, endDate: endDate, queryData: brokerQueryData)

            let optOutJobsCount = optOutJobs.count

            // If optOutCount is zero, skip to the next data broker
            guard optOutJobsCount != 0 else { continue }

            totalGlobalOptOuts += optOutJobsCount

            // Get opt-out request count since start date
            let requestsCountSinceStartDate = optOutSuccessfulRequestCountSince(startDate: startDate, for: optOutJobs)

            totalGlobalRequests += requestsCountSinceStartDate

            // Calculate opt-out success rate
            let optOutSuccessRate = optOutJobsCount > 0 ? Double(requestsCountSinceStartDate) / Double(optOutJobsCount) : 0
            let roundedOptOutSuccessRate = (optOutSuccessRate * 100).rounded() / 100

            let dataBrokerName = groupedByBroker[dataBroker]?.first?.dataBroker.name ?? ""

            let customIndividualDataBrokerStat = CustomIndividualDataBrokerStat(dataBrokerName: dataBrokerName,
                                                                                optoutSubmitSuccessRate: roundedOptOutSuccessRate)

            customIndividualDataBrokerStats.append(customIndividualDataBrokerStat)

        }

        let globalSuccessRate = totalGlobalOptOuts > 0 ? Double(totalGlobalRequests) / Double(totalGlobalOptOuts) : 0
        let roundedGlobalSuccessRate = (globalSuccessRate * 100).rounded() / 100
        let aggregateStats = CustomAggregateBrokersStat(optoutSubmitSuccessRate: roundedGlobalSuccessRate)
        return CustomOptOutStats(customIndividualDataBrokerStat: customIndividualDataBrokerStats, customAggregateBrokersStat: aggregateStats)
    }
}

private extension DefaultDataBrokerProtectionCustomOptOutStatsProvider {

    func optOutJobsBetween(startDate: Date?, endDate: Date, queryData: [BrokerProfileQueryData]) -> [OptOutJobData] {
        let allOptOuts = queryData.flatMap { $0.optOutJobData }
        return allOptOuts.filter { optOutJob in
            if let startDate = startDate {
                return optOutJob.createdDate >= startDate && optOutJob.createdDate <= endDate
            } else {
                return optOutJob.createdDate <= endDate
            }
        }
    }

    func optOutSuccessfulRequestCountSince(startDate: Date?,
                                           for optOutJobData: [OptOutJobData]) -> Int {

        return optOutJobData.reduce(0) { result, optOutJobData in
            let optOutRequested = optOutJobData.historyEvents.contains { historyEvent in
                let matchDatePlus24 = Calendar.current.date(byAdding: .hour, value: 24, to: optOutJobData.createdDate) ?? Date()
                return historyEvent.type == .optOutRequested && (historyEvent.date < matchDatePlus24 && historyEvent.date > optOutJobData.createdDate)
            }
            return result + (optOutRequested ? 1 : 0)
        }
    }
}
