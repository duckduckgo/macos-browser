//
//  DBPToApp.swift
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

/// A scheduler that works through IPC to request the scheduling to a different process
///
public final class DataBrokerProtectionIPCScheduler: DataBrokerProtectionScheduler {

    private let ipcClient: DataBrokerProtectionIPCClient

    public init(ipcClient: DataBrokerProtectionIPCClient) {
        self.ipcClient = ipcClient
    }

    public func profileModified() {
        //ipcConnection.profileModified()
        ipcClient.restart()
    }
/*
    public func startScan() {
        ipcConnection.startScanPressed()
    }
*/
    public func startScheduler(showWebView: Bool) {
        //ipcConnection.startScheduler(showWebView: showWebView)
        ipcClient.start()
    }

    public func stopScheduler() {
        //ipcConnection.stopScheduler()
        ipcClient.stop()
    }

    public func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        //ipcConnection.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        //ipcConnection.scanAllBrokers(showWebView: showWebView, completion: completion)
        ipcClient.start()
    }

    public func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) {
        //ipcConnection.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    public func runAllOperations(showWebView: Bool) {
        //ipcConnection.runAllOperations(showWebView: showWebView)
    }
}

//I'm not sure how to do this way aroung right now
@objc public protocol MainAppToDBPPackageInterface {
    func brokersScanCompleted()
}
