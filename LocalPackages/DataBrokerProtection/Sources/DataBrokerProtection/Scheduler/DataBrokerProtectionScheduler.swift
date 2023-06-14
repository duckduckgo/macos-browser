//
//  DataBrokerProtectionScheduler.swift
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

protocol SchedulerConfig {
   var runFrequency: Int { get }
   var concurrentOperationsPerBroker: Int { get }
   var concurrentOperationsDifferentBrokers: Int { get }
}

struct DataBrokerProtectionSchedulerConfig: SchedulerConfig {
   var runFrequency: Int = 4
   var concurrentOperationsPerBroker: Int = 1
   var concurrentOperationsDifferentBrokers: Int = 2
}

protocol OperationRunnerProvider {
    func getOperationRunner() -> OperationRunner
}

class DataBrokerProtectionScheduler {
    var operationManagers: [DataBrokerOperationManagerCollection]
    let database: DataBase
    let config: SchedulerConfig
    let operationRunnerProvider: OperationRunnerProvider
    let notificationCenter: NotificationCenter

    init(database: DataBase,
         config: SchedulerConfig,
         operationRunnerProvider: OperationRunnerProvider,
         notificationCenter: NotificationCenter = NotificationCenter.default) {

        self.database = database
        self.config = config
        self.operationRunnerProvider = operationRunnerProvider
        self.operationManagers = [DataBrokerOperationManagerCollection]()
        self.notificationCenter = notificationCenter
        setupManagers()
    }


    // MARK: - Public functions

    func runScanOnAllDataBrokers() async throws {
        for manager in operationManagers {
            let runner = self.operationRunnerProvider.getOperationRunner()
            try await manager.runScan(on: runner)
        }
    }

    func start() {

    }


    // MARK: - Private functions

    private func setupManagers() {
        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        self.operationManagers = createDataBrokerOperationManagerCollection(from: brokersProfileData)
    }

    private func runOptOutOperations() async throws {
        for manager in operationManagers {
            let runner = self.operationRunnerProvider.getOperationRunner()
            try await manager.runOptOut(on: runner)
        }
    }

    private func createDataBrokerOperationManagerCollection(from brokerProfileQueryDataList: [BrokerProfileQueryData]) -> [DataBrokerOperationManagerCollection] {
        var dataBrokerOperationManagerCollectionList = [DataBrokerOperationManagerCollection]()

        // Group the broker profile query data by data broker
        let groupedData = Dictionary(grouping: brokerProfileQueryDataList, by: { $0.dataBroker })

        // Create a DataBrokerOperationManagerCollection for each data broker
        for (dataBroker, brokerProfileQueryDataList) in groupedData {
            let operationManagers = brokerProfileQueryDataList.map {
                BrokerProfileQueryOperationsManager(profileQuery: $0.profileQuery,
                                                    dataBroker: dataBroker,
                                                    database: database,
                                                    notificationCenter: notificationCenter)
            }
            let dataBrokerOperationManagerCollection = DataBrokerOperationManagerCollection(dataBroker: dataBroker,
                                                                                            operationManagers: operationManagers)

            dataBrokerOperationManagerCollectionList.append(dataBrokerOperationManagerCollection)
        }

        return dataBrokerOperationManagerCollectionList
    }

    // Get next operation
    // Run Queue
    // Download JSON data
    // Handle errors?
    // How many concurrent actions?
    // Cadence on when to run the queue
    // Take into consideration error by broker not by profileQuery
}

struct DataBrokerOperationManagerCollection {
    let dataBroker: DataBroker
    let operationManagers: [OperationsManager]

    func runScan(on runner: OperationRunner) async throws {
        for manager in operationManagers {
            try await manager.runScanOperation(on: runner)
        }
    }

    func runOptOut(on runner: OperationRunner) async throws {
        for manager in operationManagers {

            try await manager.runOptOutOperations(on: runner)
        }
    }
}

struct DataBrokerNotifications {
    public static let didFinishScan = NSNotification.Name(rawValue: "com.duckduckgo.dbp.didFinishScan")
    public static let didFinishOptOut = NSNotification.Name(rawValue: "com.duckduckgo.dbp.didFinishOptOut")

}

