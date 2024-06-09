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
    var maxConcurrentOperationCount: Int { get set }
    func cancelAllOperations()
    func addOperation(_ op: Operation)
    func addBarrierBlock(_ barrier: @escaping @Sendable () -> Void)
}

extension OperationQueue: DataBrokerProtectionOperationQueue {}

enum DataBrokerProtectionQueueMode {
    case idle
    case immediate(completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?)
    case scheduled(completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?)

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
                               completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?)
}

protocol DataBrokerProtectionQueueManager {

    init(operationQueue: DataBrokerProtectionOperationQueue,
         operationsCreator: DataBrokerOperationsCreator,
         mismatchCalculator: MismatchCalculator,
         brokerUpdater: DataBrokerProtectionBrokerUpdater?,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>)

    func startImmediateOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?)
    func startScheduledOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?)

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

    func startImmediateOperationsIfPermitted(showWebView: Bool,
                                             operationDependencies: DataBrokerOperationDependencies,
                                             completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {

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
                                             completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {
        let newMode = DataBrokerProtectionQueueMode.scheduled(completion: completion)
        startOperationsIfPermitted(forNewMode: newMode,
                                   type: .all,
                                   showWebView: showWebView,
                                   operationDependencies: operationDependencies,
                                   completion: completion)
    }

    func execute(_ command: DataBrokerProtectionQueueManagerDebugCommand) {
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

    func startOperationsIfPermitted(forNewMode newMode: DataBrokerProtectionQueueMode,
                                    type: OperationType,
                                    showWebView: Bool,
                                    operationDependencies: DataBrokerOperationDependencies,
                                    completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {

        guard mode.canBeInterruptedBy(newMode: newMode) else {
            let error = DataBrokerProtectionQueueError.cannotInterrupt
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: error)
            completion?(errorCollection)
            return
        }

        cancelCurrentModeAndResetIfNeeded()

        mode = newMode

        updateBrokerData()

        firePixels(operationDependencies: operationDependencies)

        addOperations(withType: type,
                      priorityDate: mode.priorityDate,
                      showWebView: showWebView,
                      operationDependencies: operationDependencies,
                      completion: completion)
    }

    func cancelCurrentModeAndResetIfNeeded() {
        switch mode {
        case .immediate(let completion), .scheduled(let completion):
            operationQueue.cancelAllOperations()
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: DataBrokerProtectionQueueError.interrupted, operationErrors: operationErrorsForCurrentOperations())
            completion?(errorCollection)
            resetModeAndClearErrors()
        default:
            break
        }
    }

    func resetModeAndClearErrors() {
        mode = .idle
        operationErrors = []
    }

    func updateBrokerData() {
        // Update broker files if applicable
        brokerUpdater?.checkForUpdatesInBrokerJSONFiles()
    }

    func addOperations(withType type: OperationType,
                       priorityDate: Date? = nil,
                       showWebView: Bool,
                       operationDependencies: DataBrokerOperationDependencies,
                       completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {

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
            os_log("DataBrokerProtectionProcessor error: addOperations, error: %{public}@", log: .error, error.localizedDescription)
            completion?(DataBrokerProtectionAgentErrorCollection(oneTimeError: error))
            return
        }

        operationQueue.addBarrierBlock { [weak self] in
            let errorCollection = DataBrokerProtectionAgentErrorCollection(oneTimeError: nil, operationErrors: self?.operationErrorsForCurrentOperations())
            completion?(errorCollection)
            self?.resetModeAndClearErrors()
        }
    }

    func operationErrorsForCurrentOperations() -> [Error]? {
        return operationErrors.count != 0 ? operationErrors : nil
    }

    func firePixels(operationDependencies: DataBrokerOperationDependencies) {
        let database = operationDependencies.database
        let pixelHandler = operationDependencies.pixelHandler

        let engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
        let statsPixels = DataBrokerProtectionStatsPixels(database: database, handler: pixelHandler)

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()
        // This will try to fire the stats pixels
        statsPixels.tryToFireStatsPixels()
    }
}

extension DefaultDataBrokerProtectionQueueManager: DataBrokerOperationErrorDelegate {
    func dataBrokerOperationDidError(_ error: any Error, withBrokerName brokerName: String?) {
        operationErrors.append(error)

        if let error = error as? DataBrokerProtectionError, let dataBrokerName = brokerName {
            pixelHandler.fire(.error(error: error, dataBroker: dataBrokerName))
        }
    }
}
