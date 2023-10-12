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

import Foundation
import DataBrokerProtection

final class IPCService {
    private let ipcServer: DataBrokerProtectionIPCServer
    private let scheduler: DataBrokerProtectionScheduler

    init(ipcServer: DataBrokerProtectionIPCServer = .init(machServiceName: Bundle.main.bundleIdentifier!),
         scheduler: DataBrokerProtectionScheduler) {

        self.ipcServer = ipcServer
        self.scheduler = scheduler

        ipcServer.serverDelegate = self
    }
}

extension IPCService: IPCServerInterface {
    func register() {
        // no-op
    }
    
    func start() {
        scheduler.startScheduler()
    }
    
    func stop() {
        scheduler.stopScheduler()
    }
    
    func restart() {
        scheduler.stopScheduler()
        scheduler.startScheduler()
    }
}
