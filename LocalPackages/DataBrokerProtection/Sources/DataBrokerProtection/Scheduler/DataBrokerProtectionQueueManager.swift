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

enum DataBrokerProtectionQueueMode {
    case idle
    case immediate(completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    case scheduled(completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)

    func canBeInterruptedBy(newMode: DataBrokerProtectionQueueMode) -> Bool {
        switch (self, newMode) {
        case (.idle, _):
            return true
        case (_, .immediate):
            return true
        default:
            return false
        }
    }
}

protocol DataBrokerProtectionQueueManager: DataBrokerDebugCommandExecutor {

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsBuilder: DataBrokerOperationsBuilder,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?)

    func startImmediateOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    func startScheduledOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)

    func stopAllOperations()
}

final class DefaultDataBrokerProtectionQueueManager: DataBrokerProtectionQueueManager {

    private var mode = DataBrokerProtectionQueueMode.idle
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
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        let newMode = DataBrokerProtectionQueueMode.immediate(completion: completion)
        startOperationsIfPermitted(forNewMode: newMode,
                                   type: .scan,
                                   showWebView: showWebView,
                                   operationDependencies: operationDependencies) { [weak self] errors in
            completion?(errors)
            self?.mismatchCalculator.calculateMismatches()
        }
    }

    func startScheduledOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {
        let newMode = DataBrokerProtectionQueueMode.scheduled(completion: completion)
        startOperationsIfPermitted(forNewMode: newMode,
                                   type: .all,
                                   showWebView: showWebView,
                                   operationDependencies: operationDependencies,
                                   completion: completion)
    }

    func stopAllOperations() {
        operationQueue.cancelAllOperations()
    }
}

extension DefaultDataBrokerProtectionQueueManager {
    func execute(_ command: DataBrokerDebugCommand) {
        guard case .startOptOutOperations(let showWebView,
                                          let operationDependencies,
                                          let completion) = command else { return }

        addOperations(withType: .optOut,
                      showWebView: showWebView,
                      operationDependencies: operationDependencies,
                      completion: completion)
    }
}

private extension DefaultDataBrokerProtectionQueueManager {

    typealias OperationType = DataBrokerOperation.OperationType

    func startOperationsIfPermitted(forNewMode newMode: DataBrokerProtectionQueueMode,
                                    type: OperationType,
                                    showWebView: Bool,
                                    operationDependencies: DataBrokerOperationDependencies,
                                    completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        guard mode.canBeInterruptedBy(newMode: newMode) else {
            completion?(nil)
            return
        }

        cancelOperationsAndCallCompletion(forMode: mode)
        mode = newMode

        addOperations(withType: type,
                      showWebView: showWebView,
                      operationDependencies: operationDependencies,
                      completion: completion)
    }

    func cancelOperationsAndCallCompletion(forMode mode: DataBrokerProtectionQueueMode) {
        switch mode {
        case .immediate(let completion), .scheduled(let completion):
            operationQueue.cancelAllOperations()
            completion?(nil)
        default:
            break
        }
    }

    func addOperations(withType type: OperationType,
                       priorityDate: Date? = nil,
                       showWebView: Bool,
                       operationDependencies: DataBrokerOperationDependencies,
                       completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {

        // Update broker files if applicable
        brokerUpdater?.checkForUpdatesInBrokerJSONFiles()

        // Fire Pixels
        firePixels(operationDependencies: operationDependencies)

        // Use builder to build operations
        let operations: [DataBrokerOperation]
        do {
            operations = try operationsBuilder.operations(operationType: type,
                                                          priorityDate: priorityDate,
                                                          showWebView: showWebView,
                                                          operationDependencies: operationDependencies)

            for collection in operations {
                operationQueue.addOperation(collection)
            }
        } catch {
            os_log("DataBrokerProtectionProcessor error: runOperations, error: %{public}@", log: .error, error.localizedDescription)
            completion?(DataBrokerProtectionSchedulerErrorCollection(oneTimeError: error))
            return
        }

        operationQueue.addBarrierBlock {
            let operationErrors = operations.compactMap { $0.error }
            let errorCollection = operationErrors.count != 0 ? DataBrokerProtectionSchedulerErrorCollection(operationErrors: operationErrors) : nil
            completion?(errorCollection)
        }
    }

    func firePixels(operationDependencies: DataBrokerOperationDependencies) {
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
