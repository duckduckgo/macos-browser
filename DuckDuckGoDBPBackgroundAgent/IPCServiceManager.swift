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
import Foundation
import DataBrokerProtection

/// Manages the IPC service for the Agent app
///
/// This class will handle all interactions between IPC requests and the classes those requests
/// demand interaction with.
///
final class IPCServiceManager {
    private let ipcServer: DataBrokerProtectionIPCServer
    private let scheduler: DataBrokerProtectionScheduler
    private var cancellables = Set<AnyCancellable>()

    init(ipcServer: DataBrokerProtectionIPCServer = .init(machServiceName: Bundle.main.bundleIdentifier!),
         scheduler: DataBrokerProtectionScheduler) {

        self.ipcServer = ipcServer
        self.scheduler = scheduler

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

    func startScheduler() {
        scheduler.startScheduler()
    }

    func stopScheduler() {
        scheduler.stopScheduler()
    }

    func restartScheduler() {
        scheduler.stopScheduler()
        scheduler.startScheduler()
    }
}
