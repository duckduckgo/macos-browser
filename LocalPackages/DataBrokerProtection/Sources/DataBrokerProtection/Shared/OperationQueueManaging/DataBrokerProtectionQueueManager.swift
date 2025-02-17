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
import os.log

protocol DataBrokerProtectionOperationQueue {
    var maxConcurrentOperationCount: Int { get set }
    func cancelAllOperations()
    func addOperation(_ op: Operation)
    func addBarrierBlock1(_ barrier: @escaping @Sendable () -> Void)
}

extension OperationQueue: DataBrokerProtectionOperationQueue {
    func addBarrierBlock1(_ barrier: @escaping () -> Void) {
        addBarrierBlock(barrier)
    }
}

enum DataBrokerProtectionQueueMode {
    case idle
    case immediate(errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?, completion: (() -> Void)?)
    case scheduled(errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?, completion: (() -> Void)?)

    var priorityDate: Date? {
        switch self {
        case .idle, .immediate:
            return nil
        case .scheduled:
            return Date()
        }
    }

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

enum DataBrokerProtectionQueueError: Error {
    case cannotInterrupt
    case interrupted
}

enum DataBrokerProtectionQueueManagerDebugCommand {
    case startOptOutOperations(showWebView: Bool,
                               operationDependencies: DataBrokerOperationDependencies,
                               errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                               completion: (() -> Void)?)
}

protocol DataBrokerProtectionQueueManager {

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsCreator: DataBrokerOperationsCreator,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>)

    func startImmediateScanOperationsIfPermitted(showWebView: Bool,
                                                 operationDependencies: DataBrokerOperationDependencies,
                                                 errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                 completion: (() -> Void)?)
    func startScheduledAllOperationsIfPermitted(showWebView: Bool,
                                                operationDependencies: DataBrokerOperationDependencies,
                                                errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                completion: (() -> Void)?)
    func startScheduledScanOperationsIfPermitted(showWebView: Bool,
                                                 operationDependencies: DataBrokerOperationDependencies,
                                                 errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                 completion: (() -> Void)?)

    func execute(_ command: DataBrokerProtectionQueueManagerDebugCommand)
    var debugRunningStatusString: String { get }
}

final class DefaultDataBrokerProtectionQueueManager: DataBrokerProtectionQueueManager {

    private var operationQueue: DataBrokerProtectionOperationQueue
    private let operationsCreator: DataBrokerOperationsCreator
    private let mismatchCalculator: MismatchCalculator
    private let brokerUpdater: DataBrokerProtectionBrokerUpdater?
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    private var mode = DataBrokerProtectionQueueMode.idle
    private var operationErrors: [Error] = []

    var debugRunningStatusString: String {
        switch mode {
        case .idle:
            return "idle"
        case .immediate,
                .scheduled:
            return "running"
        }
    }

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsCreator: DataBrokerOperationsCreator,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>) {

        self.operationQueue = operationQueue
        self.operationsCreator = operationsCreator
        self.mismatchCalculator = mismatchCalculator
        self.brokerUpdater = brokerUpdater
        self.pixelHandler = pixelHandler
    }

    func startImmediateScanOperationsIfPermitted(showWebView: Bool,
                                                 operationDependencies: DataBrokerOperationDependencies,
                                                 errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                 completion: (() -> Void)?) {

        let newMode = DataBrokerProtectionQueueMode.immediate(errorHandler: errorHandler, completion: completion)
        startOperationsIfPermitted(forNewMode: newMode,
                                   type: .manualScan,
                                   showWebView: showWebView,
                                   operationDependencies: operationDependencies) { [weak self] errors in
            self?.mismatchCalculator.calculateMismatches()
            errorHandler?(errors)
        } completion: {
            completion?()
        }
    }

    func startScheduledAllOperationsIfPermitted(showWebView: Bool,
                                                operationDependencies: DataBrokerOperationDependencies,
                                                errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                completion: (() -> Void)?) {
        startScheduleOperationsIfPermitted(withOperationType: .all,
                                           showWebView: showWebView,
                                           operationDependencies: operationDependencies,
                                           errorHandler: errorHandler,
                                           completion: completion)
    }

    func startScheduledScanOperationsIfPermitted(showWebView: Bool,
                                                 operationDependencies: DataBrokerOperationDependencies,
                                                 errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                                 completion: (() -> Void)?) {
        startScheduleOperationsIfPermitted(withOperationType: .scheduledScan,
                                           showWebView: showWebView,
                                           operationDependencies: operationDependencies,
                                           errorHandler: errorHandler,
                                           completion: completion)
    }

    func execute(_ command: DataBrokerProtectionQueueManagerDebugCommand) {
        guard case .startOptOutOperations(let showWebView,
                                          let operationDependencies,
                                          let errorHandler,
                                          let completion) = command else { return }

        addOperations(withType: .optOut,
                      showWebView: showWebView,
                      operationDependencies: operationDependencies,
                      errorHandler: errorHandler,
                      completion: completion)
    }
}

private extension DefaultDataBrokerProtectionQueueManager {

    func startScheduleOperationsIfPermitted(withOperationType operationType: OperationType,
                                            showWebView: Bool,
                                            operationDependencies: DataBrokerOperationDependencies,
                                            errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                            completion: (() -> Void)?) {
        let newMode = DataBrokerProtectionQueueMode.scheduled(errorHandler: errorHandler, completion: completion)
        startOperationsIfPermitted(forNewMode: newMode,
                                   type: operationType,
                                   showWebView: showWebView,
                                   operationDependencies: operationDependencies,
                                   errorHandler: errorHandler,
                                   completion: completion)
    }

    func startOperationsIfPermitted(forNewMode newMode: DataBrokerProtectionQueueMode,
                                    type: OperationType,
                                    showWebView: Bool,
                                    operationDependencies: DataBrokerOperationDependencies,
                                    errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                                    completion: (() -> Void)?) {

        guard mode.canBeInterruptedBy(newMode: newMode) else {
            let error = DataBrokerProtectionQueueError.cannotInterrupt
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: error)
            errorHandler?(errorCollection)
            completion?()
            return
        }

        cancelCurrentModeAndResetIfNeeded()

        mode = newMode

        updateBrokerData()

        addOperations(withType: type,
                      priorityDate: mode.priorityDate,
                      showWebView: showWebView,
                      operationDependencies: operationDependencies,
                      errorHandler: errorHandler,
                      completion: completion)
    }

    func cancelCurrentModeAndResetIfNeeded() {
        switch mode {
        case .immediate(let errorHandler, let completion), .scheduled(let errorHandler, let completion):
            operationQueue.cancelAllOperations()
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: DataBrokerProtectionQueueError.interrupted, operationErrors: operationErrorsForCurrentOperations())
            errorHandler?(errorCollection)
            resetMode(clearErrors: true)
            completion?()
            resetMode()
        default:
            break
        }
    }

    func resetMode(clearErrors: Bool = false) {
        mode = .idle
        if clearErrors {
            operationErrors = []
        }
    }

    func updateBrokerData() {
        // Update broker files if applicable
        brokerUpdater?.checkForUpdatesInBrokerJSONFiles()
    }

    func addOperations(withType type: OperationType,
                       priorityDate: Date? = nil,
                       showWebView: Bool,
                       operationDependencies: DataBrokerOperationDependencies,
                       errorHandler: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?,
                       completion: (() -> Void)?) {

        operationQueue.maxConcurrentOperationCount = operationDependencies.config.concurrentOperationsFor(type)

        // Use builder to build operations
        let operations: [DataBrokerOperation]
        do {
            operations = try operationsCreator.operations(forOperationType: type,
                                                          withPriorityDate: priorityDate,
                                                          showWebView: showWebView,
                                                          errorDelegate: self,
                                                          operationDependencies: operationDependencies)

            for collection in operations {
                operationQueue.addOperation(collection)
            }
        } catch {
            Logger.dataBrokerProtection.error("DataBrokerProtectionProcessor error: addOperations, error: \(error.localizedDescription, privacy: .public)")
            errorHandler?(DataBrokerProtectionAgentErrorCollection(oneTimeError: error))
            completion?()
            return
        }

        operationQueue.addBarrierBlock1 { [weak self] in
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: nil, operationErrors: self?.operationErrorsForCurrentOperations())
            errorHandler?(errorCollection)
            self?.resetMode(clearErrors: true)
            completion?()
            self?.resetMode()
        }
    }

    func operationErrorsForCurrentOperations() -> [Error]? {
        return operationErrors.count != 0 ? operationErrors : nil
    }
}

extension DefaultDataBrokerProtectionQueueManager: DataBrokerOperationErrorDelegate {
    func dataBrokerOperationDidError(_ error: any Error, withBrokerName brokerName: String?) {
        operationErrors.append(error)

        guard let error = error as? DataBrokerProtectionError, let brokerName else { return }

        switch error {
        case .httpError(let code):
            pixelHandler.fire(.httpError(error: error, code: code, dataBroker: brokerName))
        case .actionFailed(let actionId, let message):
            pixelHandler.fire(.actionFailedError(error: error, actionId: actionId, message: message, dataBroker: brokerName))
        default:
            pixelHandler.fire(.otherError(error: error, dataBroker: brokerName))
        }
    }
}
