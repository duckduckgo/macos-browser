//
//  DataBrokerProtectionIPCScheduler.swift
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
import Combine
import Common

/// A scheduler that works through IPC to request the scheduling to a different process
///
public final class DataBrokerProtectionIPCScheduler: DataBrokerProtectionScheduler {

    private let ipcClient: DataBrokerProtectionIPCClient

    public init(ipcClient: DataBrokerProtectionIPCClient) {
        self.ipcClient = ipcClient
    }

    public var status: DataBrokerProtectionSchedulerStatus {
        ipcClient.schedulerStatus
    }

    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher {
        ipcClient.schedulerStatusPublisher
    }

    public func startScheduler(showWebView: Bool) {
        ipcClient.startScheduler(showWebView: showWebView)
    }

    public func stopScheduler() {
        ipcClient.stopScheduler()
    }

    public func optOutAllBrokers(showWebView: Bool, completion: ((Error?) -> Void)?) {
        let completion = completion ?? { error in }
        ipcClient.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func scanAllBrokers(showWebView: Bool, completion: ((Error?) -> Void)?) {
        let completion = completion ?? { error in }
        ipcClient.scanAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func runQueuedOperations(showWebView: Bool, completion: ((Error?) -> Void)?) {
        let completion = completion ?? { error in }
        ipcClient.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    public func runAllOperations(showWebView: Bool) {
        ipcClient.runAllOperations(showWebView: showWebView)
    }
}
