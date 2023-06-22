//
//  DataBrokerOperationsCollection.swift
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

class DataBrokerOperationsCollection: Operation {
    private let brokerProfileQueriesData: [BrokerProfileQueryData]
    private let database: DataBase
    private let id = UUID()
    private var _isExecuting = false
    private var _isFinished = false
    private let intervalBetweenOperations: TimeInterval?

    deinit {
        print("Deinit Operation \(self.id)")
    }

    init(brokerProfileQueriesData: [BrokerProfileQueryData],
         database: DataBase,
         intervalBetweenOperations: TimeInterval? = nil) {

        self.brokerProfileQueriesData = brokerProfileQueriesData
        self.database = database
        self.intervalBetweenOperations = intervalBetweenOperations
        print("New op created \(id)")
        super.init()
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }

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
                    try await DataBrokerProfileQueryOperationManager().runOperation(operationData: operationData,
                                                                            brokerProfileQueryData: brokerProfileData,
                                                                            database: database,
                                                                            runner: testRunner)
                    if let sleepInterval = intervalBetweenOperations {
                        print("Waiting \(sleepInterval) seconds...")
                        try await Task.sleep(nanoseconds: UInt64(sleepInterval) * 1_000_000_000)
                    }
                } catch {
                    print("Error: \(error)")
                }
            } else {
                print("No brokerProfileData")
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
