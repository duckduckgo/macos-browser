//
//  DataBrokerProtectionQueueManager.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Common
import Foundation

protocol DataBrokerProtectionOperationQueue {
    func cancelAllOperations()
    func addOperation(_ op: Operation)
    func addBarrierBlock(_ barrier: @escaping @Sendable () -> Void)
}

extension OperationQueue: DataBrokerProtectionOperationQueue {}

protocol DataBrokerProtectionQueueManager {
    var mode: QueueManagerMode { get }

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsBuilder: DataBrokerOperationsBuilder,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?)

    func startImmediateOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: OperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    func startScheduledOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: OperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)

    func startOptOutOperations(showWebView: Bool,
                               operationDependencies: OperationDependencies,
                               completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)

    func stopAllOperations()
}

enum QueueManagerMode {
    case idle
    case immediate
    case optOut
    case scheduled

    func canInterrupt(forNewMode newMode: QueueManagerMode) -> Bool {
        switch (self, newMode) {
        case (_, .immediate):
            return true
        case (.idle, .scheduled):
            return true
        case (.immediate, .scheduled):
            return false
        default:
            return false
        }
    }
}

final class DefaultDataBrokerProtectionQueueManager: DataBrokerProtectionQueueManager {

    private(set) var mode: QueueManagerMode = .idle

    private let operationQueue: DataBrokerProtectionOperationQueue
    private let operationsBuilder: DataBrokerOperationsBuilder
    private let mismatchCalculator: MismatchCalculator
    private let brokerUpdater: DataBrokerProtectionBrokerUpdater?

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsBuilder: DataBrokerOperationsBuilder,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?) {

        self.operationQueue = operationQueue
        self.operationsBuilder = operationsBuilder
        self.mismatchCalculator = mismatchCalculator
        self.brokerUpdater = brokerUpdater
    }

    func startImmediateOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: OperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        guard mode.canInterrupt(forNewMode: .immediate) else { return }
        mode = .immediate

        // New Manual scans ALWAYS interrupt (i.e cancel) ANY current Manual/Scheduled scans
        operationQueue.cancelAllOperations()

        // Add manual operations to queue
        addOperationCollections(withType: .scan, showWebView: showWebView, operationDependencies: operationDependencies) { [weak self] errors in
            os_log("Manual scans completed", log: .dataBrokerProtection)
            completion?(errors)
            self?.mismatchCalculator.calculateMismatches()
        }
    }

    func startScheduledOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: OperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        guard mode.canInterrupt(forNewMode: .scheduled) else { return }
        mode = .scheduled

        addOperationCollections(withType: .all,
                                priorityDate: Date(),
                                showWebView: showWebView,
                                operationDependencies: operationDependencies) { errors in
            os_log("Queued operations completed", log: .dataBrokerProtection)
            completion?(errors)
        }
    }

    func startOptOutOperations(showWebView: Bool,
                               operationDependencies: OperationDependencies,
                               completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        // TODO: Correct interruption/cancellation behavior
        // operationQueue.cancelAllOperations()

        addOperationCollections(withType: .optOut, showWebView: showWebView, operationDependencies: operationDependencies) { errors in
            os_log("Opt-Outs completed", log: .dataBrokerProtection)
            completion?(errors)
        }
    }

    func stopAllOperations() {
         operationQueue.cancelAllOperations()
    }
}

private extension DefaultDataBrokerProtectionQueueManager {

    typealias OperationType = DataBrokerOperation.OperationType

    func addOperationCollections(withType type: OperationType,
                                 priorityDate: Date? = nil,
                                 showWebView: Bool,
                                 operationDependencies: OperationDependencies,
                                 completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {

        // Update broker files if applicable
        brokerUpdater?.checkForUpdatesInBrokerJSONFiles()

        // Fire Pixels
        firePixels(operationDependencies: operationDependencies)

        // Use builder to build operations
        let operations: [DataBrokerOperation]
        do {

            operations = try operationsBuilder.operationCollections(operationType: type,
                                                                    priorityDate: priorityDate,
                                                                    showWebView: showWebView,
                                                                    operationDependencies: operationDependencies)

            for collection in operations {
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
            let operationErrors = operations.compactMap { $0.error }
            let errorCollection = operationErrors.count != 0 ? DataBrokerProtectionSchedulerErrorCollection(operationErrors: operationErrors) : nil
            completion(errorCollection)
        }
    }

    private func firePixels(operationDependencies: OperationDependencies) {
        let database = operationDependencies.database
        let pixelHandler = operationDependencies.pixelHandler

        let engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()
    }
}
