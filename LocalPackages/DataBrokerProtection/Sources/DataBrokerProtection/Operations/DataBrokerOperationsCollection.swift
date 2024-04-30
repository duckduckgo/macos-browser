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

protocol DataBrokerOperationsBuilder {
    func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData],
                                              operationType: DataBrokerOperationsCollection.OperationType,
                                              priorityDate: Date?,
                                              showWebView: Bool,
                                              database: DataBrokerProtectionRepository,
                                              intervalBetweenOperations: TimeInterval?,
                                              notificationCenter: NotificationCenter,
                                              runner: WebOperationRunner,
                                              pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                              userNotificationService: DataBrokerProtectionUserNotificationService) -> [DataBrokerOperationsCollection]

}

final class DefaultDataBrokerOperationsBuilder: DataBrokerOperationsBuilder {
    func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData],
                                              operationType: DataBrokerOperationsCollection.OperationType,
                                              priorityDate: Date?,
                                              showWebView: Bool,
                                              database: DataBrokerProtectionRepository,
                                              intervalBetweenOperations: TimeInterval? = nil,
                                              notificationCenter: NotificationCenter = NotificationCenter.default,
                                              runner: WebOperationRunner,
                                              pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                              userNotificationService: DataBrokerProtectionUserNotificationService) -> [DataBrokerOperationsCollection] {

        var collections: [DataBrokerOperationsCollection] = []
        var visitedDataBrokerIDs: Set<Int64> = []

        for queryData in brokerProfileQueriesData {

            guard let dataBrokerID = queryData.dataBroker.id else { continue }

            let groupedBrokerQueries = brokerProfileQueriesData.filter { $0.dataBroker.id == dataBrokerID }
            let filteredAndSortedOperationsData = filterAndSortOperationsData(brokerProfileQueriesData: groupedBrokerQueries,
                                                                              operationType: operationType,
                                                                              priorityDate: priorityDate)

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let collection = DataBrokerOperationsCollection(database: database,
                                                                operationType: operationType,
                                                                intervalBetweenOperations: intervalBetweenOperations,
                                                                priorityDate: priorityDate,
                                                                notificationCenter: notificationCenter,
                                                                runner: runner,
                                                                pixelHandler: pixelHandler,
                                                                userNotificationService: userNotificationService,
                                                                operationData: filteredAndSortedOperationsData,
                                                                profileQueryData: groupedBrokerQueries,
                                                                showWebView: showWebView)
                collections.append(collection)

                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return collections
    }

    private func filterAndSortOperationsData(brokerProfileQueriesData: [BrokerProfileQueryData],
                                             operationType: DataBrokerOperationsCollection.OperationType,
                                             priorityDate: Date?) -> [BrokerOperationData] {
        let operationsData: [BrokerOperationData]

        switch operationType {
        case .optOut:
            operationsData = brokerProfileQueriesData.flatMap { $0.optOutOperationsData }
        case .scan:
            operationsData = brokerProfileQueriesData.compactMap { $0.scanOperationData }
        case .all:
            operationsData = brokerProfileQueriesData.flatMap { $0.operationsData }
        }

        let filteredAndSortedOperationsData: [BrokerOperationData]

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

final class DataBrokerOperationsCollection: Operation {

    enum OperationType {
        case scan
        case optOut
        case all
    }

    public var error: Error?

    private let id = UUID()
    private var _isExecuting = false
    private var _isFinished = false

    private let database: DataBrokerProtectionRepository
    private let intervalBetweenOperations: TimeInterval? // The time in seconds to wait in-between operations
    private let priorityDate: Date? // The date to filter and sort operations priorities
    private let operationType: OperationType
    private let notificationCenter: NotificationCenter
    private let runner: WebOperationRunner
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let showWebView: Bool
    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private let operationData: [BrokerOperationData]
    private let profileQueryData: [BrokerProfileQueryData]

    deinit {
        os_log("Deinit operation: %{public}@", log: .dataBrokerProtection, String(describing: id.uuidString))
    }

    init(database: DataBrokerProtectionRepository,
         operationType: OperationType,
         intervalBetweenOperations: TimeInterval?,
         priorityDate: Date? = nil,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         runner: WebOperationRunner,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         userNotificationService: DataBrokerProtectionUserNotificationService,
         operationData: [BrokerOperationData],
         profileQueryData: [BrokerProfileQueryData],
         showWebView: Bool) {

        self.database = database
        self.intervalBetweenOperations = intervalBetweenOperations
        self.priorityDate = priorityDate
        self.operationType = operationType
        self.notificationCenter = notificationCenter
        self.runner = runner
        self.pixelHandler = pixelHandler
        self.showWebView = showWebView
        self.userNotificationService = userNotificationService
        self.operationData = operationData
        self.profileQueryData = profileQueryData
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

    private func runOperation() async {

        for operationData in operationData {
            if isCancelled {
                os_log("Cancelled operation, returning...", log: .dataBrokerProtection)
                return
            }

            let brokerProfileData = profileQueryData.filter {
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
                                                                                isManualScan: operationType == .scan,
                                                                                userNotificationService: userNotificationService,
                                                                                shouldRunNextStep: { [weak self] in
                    guard let self = self else { return false }
                    return !self.isCancelled
                })

                if let sleepInterval = intervalBetweenOperations {
                    os_log("Waiting...: %{public}f", log: .dataBrokerProtection, sleepInterval)
                    try await Task.sleep(nanoseconds: UInt64(sleepInterval) * 1_000_000_000)
                }

            } catch {
                os_log("Error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
                self.error = error
                if let error = error as? DataBrokerProtectionError,
                   let dataBrokerName = profileQueryData.first?.dataBroker.name {
                    pixelHandler.fire(.error(error: error, dataBroker: dataBrokerName))
                }
            }
        }

        finish()
    }

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
