//
//  DataBrokerProtectionProcessor.swift
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

protocol OperationRunnerProvider {
    func getOperationRunner() -> WebOperationRunner
}

final class DataBrokerProtectionProcessor {
    private let database: DataBase
    private let config: SchedulerConfig
    private let operationRunnerProvider: OperationRunnerProvider
    private let notificationCenter: NotificationCenter
    private let operationQueue: OperationQueue

    init(database: DataBase,
         config: SchedulerConfig,
         operationRunnerProvider: OperationRunnerProvider,
         notificationCenter: NotificationCenter = NotificationCenter.default) {

        self.database = database
        self.config = config
        self.operationRunnerProvider = operationRunnerProvider
        self.notificationCenter = notificationCenter
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = config.concurrentOperationsDifferentBrokers
    }

    // MARK: - Public functions
    func runScanOnAllDataBrokers() {
        // Run all data broker scans
        operationQueue.cancelAllOperations()
        runOperations(operationType: .scan, priorityDate: nil)
    }

    func runQueuedOperations() {
        runOperations(operationType: .all, priorityDate: Date())
    }

    // MARK: - Private functions
    private func runOperations(operationType: DataBrokerOperationsCollection.OperationType, priorityDate: Date?) {
        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        let dataBrokerOperationCollections = createDataBrokerOperationCollections(from: brokersProfileData,
                                                                                  operationType: operationType,
                                                                                  priorityDate: priorityDate)

        for collection in dataBrokerOperationCollections {
            operationQueue.addOperation(collection)
        }
    }

    private func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData],
                                                      operationType: DataBrokerOperationsCollection.OperationType,
                                                      priorityDate: Date?) -> [DataBrokerOperationsCollection] {

        var collections: [DataBrokerOperationsCollection] = []
        var visitedDataBrokerIDs: Set<UUID> = []

        for queryData in brokerProfileQueriesData {
            let dataBrokerID = queryData.dataBroker.id

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let matchingQueriesData = brokerProfileQueriesData.filter { $0.dataBroker.id == dataBrokerID }
                let collection = DataBrokerOperationsCollection(brokerProfileQueriesData: matchingQueriesData,
                                                                database: database,
                                                                operationType: operationType,
                                                                intervalBetweenOperations: config.intervalBetweenSameBrokerOperations,
                                                                priorityDate: priorityDate,
                                                                notificationCenter: notificationCenter)
                collections.append(collection)

                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return collections
    }
}
