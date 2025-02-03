//
//  DataBrokerOperationsCreator.swift
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

import Common
import Foundation

protocol DataBrokerOperationsCreator {
    func operations(forOperationType operationType: OperationType,
                    withPriorityDate priorityDate: Date?,
                    showWebView: Bool,
                    errorDelegate: DataBrokerOperationErrorDelegate,
                    operationDependencies: DataBrokerOperationDependencies) throws -> [DataBrokerOperation]
}

final class DefaultDataBrokerOperationsCreator: DataBrokerOperationsCreator {

    func operations(forOperationType operationType: OperationType,
                    withPriorityDate priorityDate: Date?,
                    showWebView: Bool,
                    errorDelegate: DataBrokerOperationErrorDelegate,
                    operationDependencies: DataBrokerOperationDependencies) throws -> [DataBrokerOperation] {

        let brokerProfileQueryData = try operationDependencies.database.fetchAllBrokerProfileQueryData()
        var operations: [DataBrokerOperation] = []
        var visitedDataBrokerIDs: Set<Int64> = []

        for queryData in brokerProfileQueryData {
            guard let dataBrokerID = queryData.dataBroker.id else { continue }

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let collection = DataBrokerOperation(dataBrokerID: dataBrokerID,
                                                     operationType: operationType,
                                                     priorityDate: priorityDate,
                                                     showWebView: showWebView,
                                                     errorDelegate: errorDelegate,
                                                     operationDependencies: operationDependencies)
                operations.append(collection)
                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return operations
    }
}
