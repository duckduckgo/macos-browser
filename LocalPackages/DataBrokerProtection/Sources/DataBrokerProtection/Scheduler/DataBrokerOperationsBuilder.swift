//
//  DataBrokerOperationsBuilder.swift
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

typealias OperationType = DataBrokerOperation.OperationType

protocol OperationDependencies {
    var database: DataBrokerProtectionRepository { get }
    var config: SchedulerConfig { get }
    var runnerProvider: JobRunnerProvider { get }
    var notificationCenter: NotificationCenter { get }
    var pixelHandler: EventMapping<DataBrokerProtectionPixels> { get }
    var userNotificationService: DataBrokerProtectionUserNotificationService { get }
}

struct DefaultOperationDependencies: OperationDependencies {
    let database: DataBrokerProtectionRepository
    let config: SchedulerConfig
    let runnerProvider: JobRunnerProvider
    let notificationCenter: NotificationCenter
    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    let userNotificationService: DataBrokerProtectionUserNotificationService
}

protocol DataBrokerOperationsBuilder {
    func operations(operationType: OperationType,
                    priorityDate: Date?,
                    showWebView: Bool,
                    operationDependencies: OperationDependencies) throws -> [DataBrokerOperation]
}

final class DefaultDataBrokerOperationsBuilder: DataBrokerOperationsBuilder {

    func operations(operationType: OperationType,
                    priorityDate: Date?,
                    showWebView: Bool,
                    operationDependencies: OperationDependencies) throws -> [DataBrokerOperation] {

        let brokerProfileQueryData = try operationDependencies.database.fetchAllBrokerProfileQueryData()
        var operations: [DataBrokerOperation] = []
        var visitedDataBrokerIDs: Set<Int64> = []

        for queryData in brokerProfileQueryData {
            guard let dataBrokerID = queryData.dataBroker.id else { continue }

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let collection = DataBrokerOperation(dataBrokerID: dataBrokerID,
                                                                database: operationDependencies.database,
                                                                operationType: operationType,
                                                                intervalBetweenOperations: operationDependencies.config.intervalBetweenSameBrokerOperations,
                                                                priorityDate: priorityDate,
                                                                notificationCenter: operationDependencies.notificationCenter,
                                                                runner: operationDependencies.runnerProvider.getJobRunner(),
                                                                pixelHandler: operationDependencies.pixelHandler,
                                                                userNotificationService: operationDependencies.userNotificationService,
                                                                showWebView: showWebView)
                operations.append(collection)
                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return operations
    }
}
