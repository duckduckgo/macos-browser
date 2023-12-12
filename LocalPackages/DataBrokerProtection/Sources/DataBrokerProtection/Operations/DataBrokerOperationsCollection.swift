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
import Common

final class DataBrokerOperationsCollection: Operation {

    enum OperationType {
        case scan
        case optOut
        case all
    }

    private let brokerProfileQueriesData: [BrokerProfileQueryData]
    private let database: DataBrokerProtectionRepository
    private let id = UUID()
    private var _isExecuting = false
    private var _isFinished = false
    private let intervalBetweenOperations: TimeInterval? // The time in seconds to wait in-between operations
    private let priorityDate: Date? // The date to filter and sort operations priorities
    private let operationType: OperationType
    private let notificationCenter: NotificationCenter
    private let runner: WebOperationRunner
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let showWebView: Bool

    deinit {
        os_log("Deinit operation: %{public}@", log: .dataBrokerProtection, String(describing: id.uuidString))
    }

    init(brokerProfileQueriesData: [BrokerProfileQueryData],
         database: DataBrokerProtectionRepository,
         operationType: OperationType,
         intervalBetweenOperations: TimeInterval? = nil,
         priorityDate: Date? = nil,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         runner: WebOperationRunner,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         showWebView: Bool) {

        self.brokerProfileQueriesData = brokerProfileQueriesData
        self.database = database
        self.intervalBetweenOperations = intervalBetweenOperations
        self.priorityDate = priorityDate
        self.operationType = operationType
        self.notificationCenter = notificationCenter
        self.runner = runner
        self.pixelHandler = pixelHandler
        self.showWebView = showWebView
        super.init()
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }

        willChangeValue(forKey: #keyPath(isExecuting))
        _isExecuting = true
        didChangeValue(forKey: #keyPath(isExecuting))

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

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable:next function_body_length
    private func runOperation() async {
        let filteredAndSortedOperationsData: [BrokerOperationData]
        let operationsData: [BrokerOperationData]

        switch operationType {
        case .optOut:
            operationsData = brokerProfileQueriesData.flatMap { $0.optOutOperationsData }
        case .scan:
            operationsData = brokerProfileQueriesData.compactMap { $0.scanOperationData }
        case .all:
            operationsData = brokerProfileQueriesData.flatMap { $0.operationsData }
        }

        if let priorityDate = priorityDate {
            filteredAndSortedOperationsData = operationsData
                .filter { $0.preferredRunDate != nil && $0.preferredRunDate! <= priorityDate }
                .sorted { $0.preferredRunDate! < $1.preferredRunDate! }

        } else {
            filteredAndSortedOperationsData = operationsData
        }

        for operationData in filteredAndSortedOperationsData {
            if isCancelled {
                os_log("Cancelled operation, returning...", log: .dataBrokerProtection)
                return
            }

            let brokerProfileData = brokerProfileQueriesData.filter {
                $0.dataBroker.id == operationData.brokerId && $0.profileQuery.id == operationData.profileQueryId
            }.first

            guard let brokerProfileData = brokerProfileData else {
                continue
            }
            do {
                os_log("Running operation: %{public}@", log: .dataBrokerProtection, String(describing: operationData))

                try await DataBrokerProfileQueryOperationManager().runOperation(operationData: operationData,
                                                                                brokerProfileQueryData: brokerProfileData,
                                                                                database: database,
                                                                                notificationCenter: notificationCenter,
                                                                                runner: runner,
                                                                                pixelHandler: pixelHandler,
                                                                                showWebView: showWebView,
                                                                                shouldRunNextStep: { [weak self] in
                    guard let self = self else { return false }
                    return !self.isCancelled
                })

                if let sleepInterval = intervalBetweenOperations {
                    os_log("Waiting...: %{public}f", log: .dataBrokerProtection, sleepInterval)
                    try await Task.sleep(nanoseconds: UInt64(sleepInterval) * 1_000_000_000)
                }

                finish()

            } catch {
                os_log("Error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
                if let error = error as? DataBrokerProtectionError,
                   let dataBrokerName = brokerProfileQueriesData.first?.dataBroker.name {
                    pixelHandler.fire(.error(error: error, dataBroker: dataBrokerName))
                } else {
                    os_log("Cant handle error", log: .dataBrokerProtection)
                }
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func finish() {
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))

        _isExecuting = false
        _isFinished = true

        didChangeValue(forKey: #keyPath(isExecuting))
        didChangeValue(forKey: #keyPath(isFinished))

        os_log("Finished operation: %{public}@", log: .dataBrokerProtection, String(describing: id.uuidString))
    }
}
