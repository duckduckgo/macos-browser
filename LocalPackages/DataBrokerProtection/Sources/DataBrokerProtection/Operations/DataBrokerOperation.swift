//
//  DataBrokerOperation.swift
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
import os.log

protocol DataBrokerOperationDependencies {
    var database: DataBrokerProtectionRepository { get }
    var config: DataBrokerExecutionConfig { get }
    var runnerProvider: JobRunnerProvider { get }
    var notificationCenter: NotificationCenter { get }
    var pixelHandler: EventMapping<DataBrokerProtectionPixels> { get }
    var userNotificationService: DataBrokerProtectionUserNotificationService { get }
}

struct DefaultDataBrokerOperationDependencies: DataBrokerOperationDependencies {
    let database: DataBrokerProtectionRepository
    var config: DataBrokerExecutionConfig
    let runnerProvider: JobRunnerProvider
    let notificationCenter: NotificationCenter
    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    let userNotificationService: DataBrokerProtectionUserNotificationService
}

enum OperationType {
    case manualScan
    case scheduledScan
    case optOut
    case all
}

protocol DataBrokerOperationErrorDelegate: AnyObject {
    func dataBrokerOperationDidError(_ error: Error, withBrokerName brokerName: String?)
}

// swiftlint:disable explicit_non_final_class
class DataBrokerOperation: Operation, @unchecked Sendable {

    private let dataBrokerID: Int64
    private let operationType: OperationType
    private let priorityDate: Date? // The date to filter and sort operations priorities
    private let showWebView: Bool
    private(set) weak var errorDelegate: DataBrokerOperationErrorDelegate? // Internal read-only to enable mocking
    private let operationDependencies: DataBrokerOperationDependencies

    private let id = UUID()
    private var _isExecuting = false
    private var _isFinished = false

    deinit {
        Logger.dataBrokerProtection.log("Deinit operation: \(String(describing: self.id.uuidString), privacy: .public)")
    }

    init(dataBrokerID: Int64,
         operationType: OperationType,
         priorityDate: Date? = nil,
         showWebView: Bool,
         errorDelegate: DataBrokerOperationErrorDelegate,
         operationDependencies: DataBrokerOperationDependencies) {

        self.dataBrokerID = dataBrokerID
        self.priorityDate = priorityDate
        self.operationType = operationType
        self.showWebView = showWebView
        self.errorDelegate = errorDelegate
        self.operationDependencies = operationDependencies
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

    static func filterAndSortOperationsData(brokerProfileQueriesData: [BrokerProfileQueryData], operationType: OperationType, priorityDate: Date?) -> [BrokerJobData] {
        let operationsData: [BrokerJobData]

        switch operationType {
        case .optOut:
            operationsData = brokerProfileQueriesData.flatMap { $0.optOutJobData }
        case .manualScan, .scheduledScan:
            operationsData = brokerProfileQueriesData.filter { $0.profileQuery.deprecated == false }.compactMap { $0.scanJobData }
        case .all:
            operationsData = brokerProfileQueriesData.flatMap { $0.operationsData }
        }

        let filteredAndSortedOperationsData: [BrokerJobData]

        if let priorityDate = priorityDate {
            filteredAndSortedOperationsData = operationsData
                .eligibleForRun(byDate: priorityDate)
                .sortedByPreferredRunDate()
        } else {
            filteredAndSortedOperationsData = operationsData
        }

        return filteredAndSortedOperationsData
    }

    private func runOperation() async {
        let allBrokerProfileQueryData: [BrokerProfileQueryData]

        do {
            allBrokerProfileQueryData = try operationDependencies.database.fetchAllBrokerProfileQueryData()
        } catch {
            Logger.dataBrokerProtection.error("DataBrokerOperationsCollection error: runOperation, error: \(error.localizedDescription, privacy: .public)")
            return
        }

        let brokerProfileQueriesData = allBrokerProfileQueryData.filter { $0.dataBroker.id == dataBrokerID }

        let filteredAndSortedOperationsData = Self.filterAndSortOperationsData(brokerProfileQueriesData: brokerProfileQueriesData,
                                                                               operationType: operationType,
                                                                               priorityDate: priorityDate)

        Logger.dataBrokerProtection.log("filteredAndSortedOperationsData count: \(filteredAndSortedOperationsData.count, privacy: .public) for brokerID \(self.dataBrokerID, privacy: .public)")

        for operationData in filteredAndSortedOperationsData {
            if isCancelled {
                Logger.dataBrokerProtection.log("Cancelled operation, returning...")
                return
            }

            let brokerProfileData = brokerProfileQueriesData.filter {
                $0.dataBroker.id == operationData.brokerId && $0.profileQuery.id == operationData.profileQueryId
            }.first

            guard let brokerProfileData = brokerProfileData else {
                continue
            }
            do {
                Logger.dataBrokerProtection.log("Running operation: \(String(describing: operationData), privacy: .public)")

                try await DataBrokerProfileQueryOperationManager().runOperation(operationData: operationData,
                                                                                brokerProfileQueryData: brokerProfileData,
                                                                                database: operationDependencies.database,
                                                                                notificationCenter: operationDependencies.notificationCenter,
                                                                                runner: operationDependencies.runnerProvider.getJobRunner(),
                                                                                pixelHandler: operationDependencies.pixelHandler,
                                                                                showWebView: showWebView,
                                                                                isImmediateOperation: operationType == .manualScan,
                                                                                userNotificationService: operationDependencies.userNotificationService,
                                                                                shouldRunNextStep: { [weak self] in
                    guard let self = self else { return false }
                    return !self.isCancelled
                })

                let sleepInterval = operationDependencies.config.intervalBetweenSameBrokerOperations
                Logger.dataBrokerProtection.log("Waiting...: \(sleepInterval, privacy: .public)")
                try await Task.sleep(nanoseconds: UInt64(sleepInterval) * 1_000_000_000)
            } catch {
                Logger.dataBrokerProtection.error("Error: \(error.localizedDescription, privacy: .public)")

                errorDelegate?.dataBrokerOperationDidError(error, withBrokerName: brokerProfileQueriesData.first?.dataBroker.name)
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

        Logger.dataBrokerProtection.log("Finished operation: \(self.id.uuidString, privacy: .public)")
    }
}
// swiftlint:enable explicit_non_final_class

extension Array where Element == BrokerJobData {
    /// Filters jobs based on their preferred run date:
    /// - Opt-out jobs with no preferred run date are included.
    /// - Jobs with a preferred run date on or before the priority date are included.
    ///
    /// Note: Opt-out jobs without a preferred run date may be:
    /// 1. From child brokers (will be skipped during runOptOutOperation).
    /// 2. From former child brokers now acting as parent brokers (will be processed if extractedProfile hasn't been removed).
    func eligibleForRun(byDate priorityDate: Date) -> [BrokerJobData] {
        filter { jobData in
            guard let preferredRunDate = jobData.preferredRunDate else {
                return jobData is OptOutJobData
            }

            return preferredRunDate <= priorityDate
        }
    }

    /// Sorts BrokerJobData array based on their preferred run dates.
    /// - Jobs with non-nil preferred run dates are sorted in ascending order (earliest date first).
    /// - Opt-out jobs with nil preferred run dates come last, maintaining their original relative order.
    func sortedByPreferredRunDate() -> [BrokerJobData] {
        sorted { lhs, rhs in
            switch (lhs.preferredRunDate, rhs.preferredRunDate) {
            case (nil, nil):
                return false
            case (_, nil):
                return true
            case (nil, _):
                return false
            case (let lhsRunDate?, let rhsRunDate?):
                return lhsRunDate < rhsRunDate
            }
        }
    }
}
