//
//  IPCServiceManager.swift
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

import Combine
import Common
import DataBrokerProtection
import Foundation
import PixelKit

/// Manages the IPC service for the Agent app
///
/// This class will handle all interactions between IPC requests and the classes those requests
/// demand interaction with.
///
final class IPCServiceManager {
    private var browserWindowManager: BrowserWindowManager
    private let ipcServer: DataBrokerProtectionIPCServer
    private let scheduler: DataBrokerProtectionScheduler
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private var cancellables = Set<AnyCancellable>()

    init(ipcServer: DataBrokerProtectionIPCServer = .init(machServiceName: Bundle.main.bundleIdentifier!),
         scheduler: DataBrokerProtectionScheduler,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>) {

        self.ipcServer = ipcServer
        self.scheduler = scheduler
        self.pixelHandler = pixelHandler

        browserWindowManager = BrowserWindowManager()

        ipcServer.serverDelegate = self
        ipcServer.activate()
    }

    private func subscribeToSchedulerStatusChanges() {
        scheduler.statusPublisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.ipcServer.schedulerStatusChanges(status)
            }
            .store(in: &cancellables)
    }
}

extension IPCServiceManager: IPCServerInterface {

    func register() {
        // When a new client registers, send the last known status
        ipcServer.schedulerStatusChanges(scheduler.status)
    }

    func startScheduler(showWebView: Bool) {
        pixelHandler.fire(.ipcServerStartSchedulerReceivedByAgent)
        scheduler.startScheduler(showWebView: showWebView)
    }

    func stopScheduler() {
        pixelHandler.fire(.ipcServerStopSchedulerReceivedByAgent)
        scheduler.stopScheduler()
    }

    func optOutAllBrokers(showWebView: Bool,
                          completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {
        pixelHandler.fire(.ipcServerOptOutAllBrokers)
        scheduler.optOutAllBrokers(showWebView: showWebView) { errors in
            self.pixelHandler.fire(.ipcServerOptOutAllBrokersCompletion(error: errors?.oneTimeError))
            completion(errors)
        }
    }

    func scanAllBrokers(showWebView: Bool,
                        completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {
        pixelHandler.fire(.ipcServerScanAllBrokersReceivedByAgent)
        scheduler.scanAllBrokers(showWebView: showWebView) { errors in
            if let error = errors?.oneTimeError {
                switch error {
                case DataBrokerProtectionSchedulerError.operationsInterrupted:
                    self.pixelHandler.fire(.ipcServerScanAllBrokersInterruptedOnAgent)
                default:
                    self.pixelHandler.fire(.ipcServerScanAllBrokersCompletedOnAgentWithError(error: error))
                }
            } else {
                self.pixelHandler.fire(.ipcServerScanAllBrokersCompletedOnAgentWithoutError)
            }
            completion(errors)
        }
    }

    func runQueuedOperations(showWebView: Bool,
                             completion: @escaping ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)) {
        pixelHandler.fire(.ipcServerRunQueuedOperations)
        scheduler.runQueuedOperations(showWebView: showWebView) { errors in
            self.pixelHandler.fire(.ipcServerRunQueuedOperationsCompletion(error: errors?.oneTimeError))
            completion(errors)
        }
    }

    func runAllOperations(showWebView: Bool) {
        pixelHandler.fire(.ipcServerRunAllOperations)
        scheduler.runAllOperations(showWebView: showWebView)
    }

    func openBrowser(domain: String) {
        Task { @MainActor in
            browserWindowManager.show(domain: domain)
        }
    }
}
