//
//  DuckDuckGoAgentAppDelegate.swift
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

import Cocoa
import Combine
import Common
import ServiceManagement
import DataBrokerProtection
import BrowserServicesKit

@objc(Application)
final class DuckDuckGoDBPBackgroundAgentApplication: NSApplication {
    private let _delegate = DuckDuckGoDBPBackgroundAgentAppDelegate()

    override init() {
        os_log(.error, log: .dbpBackgroundAgent, "🟢 DBP background Agent starting: %{public}d", NSRunningApplication.current.processIdentifier)

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            os_log(.error, log: .dbpBackgroundAgent, "🔴 Stopping: another instance is running: %{public}d.", anotherInstance.processIdentifier)
            exit(0)
        }

        super.init()
        self.delegate = _delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@main
final class DuckDuckGoDBPBackgroundAgentAppDelegate: NSObject, NSApplicationDelegate {

    let ipcConnection = DBPIPCConnection(log: .dbpBackgroundAgent, memoryManagementLog: .dbpBackgroundAgentMemoryManagement)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("DuckDuckGoAgent started", log: .dbpBackgroundAgent, type: .info)
        ipcConnection.startListener()

        let manager = DataBrokerProtectionBackgroundManager.shared
        manager.runOperationsAndStartSchedulerIfPossible()
        //TODO not this?
    }
}

extension DBPIPCConnection: MainAppToDBPBackgroundAgentCommunication {
    public func register(_ completionHandler: @escaping (Bool) -> Void) {
        os_log("App registered", log: .dbpBackgroundAgent, type: .debug)
        completionHandler(true)
    }

    public func appDidStart() {
        /*
         TODO
         Then running "RunQueuedOperations", and on the completion handler for that,
         Starting the scheduler
         */
    }

    public func profileModified() {
        // TODO stop the scheduler
    }

    public func startScanPressed() {
        /*
         TODO
         Initialising the agent (if it isn't already)
         scheduler.stopScheduler(), and then
         scheduler.scanAllBrokers
         */
    }

    // MARK: Debug features

    public func startScheduler(showWebView: Bool) {

    }

    public func stopScheduler() {

    }

    public func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        
    }

    public func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) {

    }

    public func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) {

    }

    public func runAllOperations(showWebView: Bool) {

    }
}

