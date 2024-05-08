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
import Common
import BrowserServicesKit

final class DataBrokerProtectionProcessor {
    private let database: DataBrokerProtectionRepository
    private let config: DataBrokerProtectionProcessorConfiguration
    private let jobRunnerProvider: JobRunnerProvider
    private let notificationCenter: NotificationCenter
    private let operationQueue: OperationQueue
    private var pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private let engagementPixels: DataBrokerProtectionEngagementPixels
    private let eventPixels: DataBrokerProtectionEventPixels

    init(database: DataBrokerProtectionRepository,
         config: DataBrokerProtectionProcessorConfiguration = DataBrokerProtectionProcessorConfiguration(),
         jobRunnerProvider: JobRunnerProvider,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         userNotificationService: DataBrokerProtectionUserNotificationService) {

        self.database = database
        self.config = config
        self.jobRunnerProvider = jobRunnerProvider
        self.notificationCenter = notificationCenter
        self.operationQueue = OperationQueue()
        self.pixelHandler = pixelHandler
        self.userNotificationService = userNotificationService
        self.engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
        self.eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
    }

    // MARK: - Public functions
    func startManualScans(showWebView: Bool = false,
                          completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil) {

        operationQueue.cancelAllOperations()
        runOperations(operationType: .manualScan,
                      priorityDate: nil,
                      showWebView: showWebView) { errors in
            os_log("Scans done", log: .dataBrokerProtection)
            completion?(errors)
            self.calculateMisMatches()
        }
    }

    private func calculateMisMatches() {
        let mismatchUseCase = MismatchCalculatorUseCase(database: database, pixelHandler: pixelHandler)
        mismatchUseCase.calculateMismatches()
    }

    func runAllOptOutOperations(showWebView: Bool = false,
                                completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil) {
        operationQueue.cancelAllOperations()
        runOperations(operationType: .optOut,
                      priorityDate: nil,
                      showWebView: showWebView) { errors in
            os_log("Optouts done", log: .dataBrokerProtection)
            completion?(errors)
        }
    }

    func runQueuedOperations(showWebView: Bool = false,
                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil ) {
        runOperations(operationType: .all,
                      priorityDate: Date(),
                      showWebView: showWebView) { errors in
            os_log("Queued operations done", log: .dataBrokerProtection)
            completion?(errors)
        }
    }

    func runAllOperations(showWebView: Bool = false,
                          completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil ) {
        runOperations(operationType: .all,
                      priorityDate: nil,
                      showWebView: showWebView) { errors in
            os_log("Queued operations done", log: .dataBrokerProtection)
            completion?(errors)
        }
    }

    func stopAllOperations() {
        operationQueue.cancelAllOperations()
    }

    // MARK: - Private functions
    private func runOperations(operationType: OperationType,
                               priorityDate: Date?,
                               showWebView: Bool,
                               completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {

        self.operationQueue.maxConcurrentOperationCount = config.concurrentOperationsFor(operationType)
        // Before running new operations we check if there is any updates to the broker files.
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: DataBrokerProtectionSecureVaultErrorReporter.shared) {
            let brokerUpdater = DataBrokerProtectionBrokerUpdater(vault: vault, pixelHandler: pixelHandler)
            brokerUpdater.checkForUpdatesInBrokerJSONFiles()
        }

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()

        let operations: [DataBrokerOperation]

        do {
            // Note: The next task in this project will inject the dependencies & builder into our new 'QueueManager' type

            let dependencies = DefaultDataBrokerOperationDependencies(database: database,
                                                                      brokerTimeInterval: config.intervalBetweenSameBrokerOperations,
                                                                      runnerProvider: jobRunnerProvider,
                                                                      notificationCenter: notificationCenter,
                                                                      pixelHandler: pixelHandler,
                                                                      userNotificationService: userNotificationService)

            operations = try DefaultDataBrokerOperationsCreator().operations(forOperationType: operationType,
                                                                             withPriorityDate: priorityDate,
                                                                             showWebView: showWebView,
                                                                             operationDependencies: dependencies)

            for operation in operations {
                operationQueue.addOperation(operation)
            }
        } catch {
            os_log("DataBrokerProtectionProcessor error: runOperations, error: %{public}@", log: .error, error.localizedDescription)
            operationQueue.addBarrierBlock {
                completion(DataBrokerProtectionSchedulerErrorCollection(oneTimeError: error))
            }
            return
        }

        operationQueue.addBarrierBlock {
            let operationErrors = operations.compactMap { $0.error }
            let errorCollection = operationErrors.count != 0 ? DataBrokerProtectionSchedulerErrorCollection(operationErrors: operationErrors) : nil
            completion(errorCollection)
        }
    }

    deinit {
        os_log("Deinit DataBrokerProtectionProcessor", log: .dataBrokerProtection)
    }
}
