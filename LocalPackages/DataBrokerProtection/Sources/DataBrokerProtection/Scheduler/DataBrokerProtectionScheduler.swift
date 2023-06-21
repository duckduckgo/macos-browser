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
    var runFrequency: TimeInterval { get }
    var concurrentOperationsPerBroker: Int { get }
    var concurrentOperationsDifferentBrokers: Int { get }
    var intervalBetweenSameBrokerOperations: TimeInterval { get }
}

struct DataBrokerProtectionSchedulerConfig: SchedulerConfig {
    var runFrequency: TimeInterval = 4 * 60 * 60
    var concurrentOperationsPerBroker: Int = 1
    var concurrentOperationsDifferentBrokers: Int = 2
    var intervalBetweenSameBrokerOperations: TimeInterval = 1 * 60
}

protocol OperationRunnerProvider {
    func getOperationRunner() -> OperationRunner
}

final class DataBrokerProtectionScheduler {
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
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public functions
    func runScanOnAllDataBrokers() async throws {
        // Run all data broker scans
    }

    func start() {
        runOperations()
        print("ENDED")
    }

    // MARK: - Private functions

    private func runOperations() {
        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        let dataBrokerOperationCollections = createDataBrokerOperationCollections(from: brokersProfileData)

        for collection in dataBrokerOperationCollections {
            Task {
                try? await collection.runOperations()
            }
        }

    }

    func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData]) -> [DataBrokerOperationCollection] {
        var collections: [DataBrokerOperationCollection] = []
        var visitedDataBrokerIDs: Set<UUID> = []

        for queryData in brokerProfileQueriesData {
            let dataBrokerID = queryData.dataBroker.id

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let matchingQueriesData = brokerProfileQueriesData.filter { $0.dataBroker.id == dataBrokerID }
                let collection = DataBrokerOperationCollection(brokerProfileQueriesData: matchingQueriesData,
                                                               database: database)
                collections.append(collection)

                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return collections
    }
}


struct DataBrokerNotifications {
    public static let didFinishScan = NSNotification.Name(rawValue: "com.duckduckgo.dbp.didFinishScan")
    public static let didFinishOptOut = NSNotification.Name(rawValue: "com.duckduckgo.dbp.didFinishOptOut")

}

struct DataBrokerOperationCollection {
    let brokerProfileQueriesData: [BrokerProfileQueryData]
    let database: DataBase
    let id = UUID()

    func runOperations() async throws {
        let ids = brokerProfileQueriesData.map { $0.dataBroker.id }
        print("Running operation \(id) ON \(ids)")
        let currentDate = Date()

        let sortedOperationsData = brokerProfileQueriesData.flatMap { $0.operationsData }
            .filter { $0.preferredRunDate != nil && $0.preferredRunDate! <= currentDate }
            .sorted { $0.preferredRunDate! < $1.preferredRunDate!}

        print("SORTED \(sortedOperationsData.count)")
        
        for operationData in sortedOperationsData {
            let brokerProfileData = brokerProfileQueriesData.filter { $0.id == operationData.brokerProfileQueryID }.first

            let testRunner = await TestOperationRunner()
            if let brokerProfileData = brokerProfileData {
                try await BrokerProfileQueryOperationsManager().runOperation(operationData: operationData,
                                                                             brokerProfileQueryData: brokerProfileData,
                                                                             database: database,
                                                                             runner: testRunner)
            } else {
                print("NO")
            }
        }
        print("Finished operation \(id)")
    }
}
