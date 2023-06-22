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
    var concurrentOperationsDifferentBrokers: Int { get }
    var intervalBetweenSameBrokerOperations: TimeInterval { get }
}

struct DataBrokerProtectionSchedulerConfig: SchedulerConfig {
    var runFrequency: TimeInterval = 4 * 60 * 60
    var concurrentOperationsDifferentBrokers: Int = 1
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
    let operationQueue: OperationQueue

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
    func runScanOnAllDataBrokers() async throws {
        // Run all data broker scans
    }

    func start() {
        runScheduledOperations()
        print("ENDED")
    }

    // MARK: - Private functions

    private func runScheduledOperations() {
        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        let dataBrokerOperationCollections = createDataBrokerOperationCollections(from: brokersProfileData)

        for collection in dataBrokerOperationCollections {
            operationQueue.addOperation(collection)
        }
    }

    func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData]) -> [DataBrokerCollectionOperation] {
        var collections: [DataBrokerCollectionOperation] = []
        var visitedDataBrokerIDs: Set<UUID> = []

        for queryData in brokerProfileQueriesData {
            let dataBrokerID = queryData.dataBroker.id

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let matchingQueriesData = brokerProfileQueriesData.filter { $0.dataBroker.id == dataBrokerID }
                let collection = DataBrokerCollectionOperation(brokerProfileQueriesData: matchingQueriesData,
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

class DataBrokerCollectionOperation: Operation {
    private let brokerProfileQueriesData: [BrokerProfileQueryData]
    private let database: DataBase
    private let id = UUID()
    private var _isExecuting = false
    private var _isFinished = false

    deinit {
        print("Deinit Operation \(self.id)")
    }

    init(brokerProfileQueriesData: [BrokerProfileQueryData], database: DataBase) {
        self.brokerProfileQueriesData = brokerProfileQueriesData
        self.database = database
        print("New op created \(id)")
        super.init()
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }

        // Mark the operation as executing
        willChangeValue(forKey: "isExecuting")
        _isExecuting = true
        didChangeValue(forKey: "isExecuting")

        main()
    }

    override var isAsynchronous: Bool {
        return true
    }

    override var isExecuting: Bool {
        return _isExecuting
    }

    override var isFinished: Bool {
        return _isFinished
    }

    override func main() {
        Task {
            await runOperation()
            finish()
        }

    }

    private func runOperation() async  {
        let ids = brokerProfileQueriesData.map { $0.dataBroker.id }
        print("Running operation \(id) ON \(ids)")
        let currentDate = Date()

        let sortedOperationsData = brokerProfileQueriesData.flatMap { $0.operationsData }
            .filter { $0.preferredRunDate != nil && $0.preferredRunDate! <= currentDate }
            .sorted { $0.preferredRunDate! < $1.preferredRunDate! }

        print("SORTED \(sortedOperationsData.count)")

        for operationData in sortedOperationsData {
            if isCancelled {
                return
            }

            let brokerProfileData = brokerProfileQueriesData.filter { $0.id == operationData.brokerProfileQueryID }.first

            let testRunner = await TestOperationRunner()
            if let brokerProfileData = brokerProfileData {
                do {
                    try await BrokerProfileQueryOperationsManager().runOperation(operationData: operationData,
                                                                            brokerProfileQueryData: brokerProfileData,
                                                                            database: database,
                                                                            runner: testRunner)
                } catch {
                    print("Error: \(error)")
                }
            } else {
                print("NO")
            }
        }
        print("Finished operation \(id)")
    }

    private func finish() {
        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")

        _isExecuting = false
        _isFinished = true
        print("Operation \(id): done")

        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
}
