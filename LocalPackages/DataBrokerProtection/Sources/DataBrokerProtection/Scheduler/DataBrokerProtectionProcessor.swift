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

protocol OperationRunnerProvider {
    func getOperationRunner() -> WebOperationRunner
}

final class DataBrokerProtectionProcessor {
    private let database: DataBrokerProtectionRepository
    private let config: SchedulerConfig
    private let operationRunnerProvider: OperationRunnerProvider
    private let notificationCenter: NotificationCenter
    private let operationQueue: OperationQueue
    private var pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private let engagementPixels: DataBrokerProtectionEngagementPixels
    private let eventPixels: DataBrokerProtectionEventPixels

    init(database: DataBrokerProtectionRepository,
         config: SchedulerConfig,
         operationRunnerProvider: OperationRunnerProvider,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         userNotificationService: DataBrokerProtectionUserNotificationService) {

        self.database = database
        self.config = config
        self.operationRunnerProvider = operationRunnerProvider
        self.notificationCenter = notificationCenter
        self.operationQueue = OperationQueue()
        self.pixelHandler = pixelHandler
        self.operationQueue.maxConcurrentOperationCount = config.concurrentOperationsDifferentBrokers
        self.userNotificationService = userNotificationService
        self.engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
        self.eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
    }

    // MARK: - Public functions
    func startManualScans(showWebView: Bool = false,
                          completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil) {

        operationQueue.cancelAllOperations()
        runOperations(operationType: .scan,
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
    private func runOperations(operationType: DataBrokerOperationsCollection.OperationType,
                               priorityDate: Date?,
                               showWebView: Bool,
                               completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {

        // Before running new operations we check if there is any updates to the broker files.
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: DataBrokerProtectionSecureVaultErrorReporter.shared) {
            let brokerUpdater = DefaultDataBrokerProtectionBrokerUpdater(vault: vault, pixelHandler: pixelHandler)
        }

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()

        let dataBrokerOperationCollections: [DataBrokerOperationsCollection]

        do {
            let brokersProfileData = try database.fetchAllBrokerProfileQueryData()
            dataBrokerOperationCollections = createDataBrokerOperationCollections(from: brokersProfileData,
                                                                                      operationType: operationType,
                                                                                      priorityDate: priorityDate,
                                                                                      showWebView: showWebView)

            for collection in dataBrokerOperationCollections {
                operationQueue.addOperation(collection)
            }
        } catch {
            os_log("DataBrokerProtectionProcessor error: runOperations, error: %{public}@", log: .error, error.localizedDescription)
            operationQueue.addBarrierBlock {
                completion(DataBrokerProtectionSchedulerErrorCollection(oneTimeError: error))
            }
            return
        }

        operationQueue.addBarrierBlock {
            let operationErrors = dataBrokerOperationCollections.compactMap { $0.error }
            let errorCollection = operationErrors.count != 0 ? DataBrokerProtectionSchedulerErrorCollection(operationErrors: operationErrors) : nil
            completion(errorCollection)
        }
    }

    private func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData],
                                                      operationType: DataBrokerOperationsCollection.OperationType,
                                                      priorityDate: Date?,
                                                      showWebView: Bool) -> [DataBrokerOperationsCollection] {

        var collections: [DataBrokerOperationsCollection] = []
        var visitedDataBrokerIDs: Set<Int64> = []

        for queryData in brokerProfileQueriesData {
            guard let dataBrokerID = queryData.dataBroker.id else { continue }

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let collection = DataBrokerOperationsCollection(dataBrokerID: dataBrokerID,
                                                                database: database,
                                                                operationType: operationType,
                                                                intervalBetweenOperations: config.intervalBetweenSameBrokerOperations,
                                                                priorityDate: priorityDate,
                                                                notificationCenter: notificationCenter,
                                                                runner: operationRunnerProvider.getOperationRunner(),
                                                                pixelHandler: pixelHandler,
                                                                userNotificationService: userNotificationService,
                                                                showWebView: showWebView)
                collection.errorDelegate = self
                collections.append(collection)

                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return collections
    }

    deinit {
        os_log("Deinit DataBrokerProtectionProcessor", log: .dataBrokerProtection)
    }
}

extension DataBrokerProtectionProcessor: DataBrokerOperationsCollectionErrorDelegate {

    func dataBrokerOperationsCollection(_ dataBrokerOperationsCollection: DataBrokerOperationsCollection, didErrorBeforeStartingBrokerOperations error: Error) {

    }

    func dataBrokerOperationsCollection(_ dataBrokerOperationsCollection: DataBrokerOperationsCollection,
                                        didError error: Error,
                                        whileRunningBrokerOperationData: BrokerOperationData,
                                        withDataBrokerName dataBrokerName: String?) {
        if let error = error as? DataBrokerProtectionError,
           let dataBrokerName = dataBrokerName {
            pixelHandler.fire(.error(error: error, dataBroker: dataBrokerName))
        } else {
            os_log("Cant handle error", log: .dataBrokerProtection)
        }
    }
}
