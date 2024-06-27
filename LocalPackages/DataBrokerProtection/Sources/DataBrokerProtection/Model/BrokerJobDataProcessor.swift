//
//  BrokerJobDataProcessor.swift
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

/// Type which filters and sorts `BrokerProfileQueryData` to create `BrokerJobData`
protocol BrokerJobDataProcessor {

    func filteredAndSortedJobData(forQueryData queryData: [BrokerProfileQueryData],
                                  operationType: OperationType,
                                  priorityDate: Date?) -> [BrokerJobData]
}

/// Default implementation of `BrokerJobDataProcessor`
struct DefaultBrokerJobDataProcessor: BrokerJobDataProcessor {
    
    func filteredAndSortedJobData(forQueryData queryData: [BrokerProfileQueryData],
                                  operationType: OperationType,
                                  priorityDate: Date?) -> [BrokerJobData] {
        
        let operationsData: [BrokerJobData]

        switch operationType {
        case .optOut:
            operationsData = queryData.flatMap { $0.optOutJobData }
        case .scan:
            operationsData = queryData.filter { $0.profileQuery.deprecated == false }.compactMap { $0.scanJobData }
        case .all:
            operationsData = queryData.flatMap { $0.operationsData }
        }

        let filteredAndSortedOperationsData: [BrokerJobData]

        if let priorityDate = priorityDate {
            filteredAndSortedOperationsData = operationsData
                .filter { $0.preferredRunDate != nil && $0.preferredRunDate! <= priorityDate }
                .sorted { $0.preferredRunDate! < $1.preferredRunDate! }
        } else {
            filteredAndSortedOperationsData = operationsData
        }

        return filteredAndSortedOperationsData
    }
}

