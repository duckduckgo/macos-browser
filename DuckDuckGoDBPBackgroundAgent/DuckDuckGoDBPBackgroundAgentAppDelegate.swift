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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("DuckDuckGoAgent started", log: .dbpBackgroundAgent, type: .info)

        let manager = DataBrokerProtectionBackgroundManager.shared
        manager.runOperationsAndStartSchedulerIfPossible()
        // TODO: remove this?
        // Although if app is not running we should run anyway
        // Does anything go wrong if we run runQueuedOperations twice? Does it matter?
    }
}
/*
extension DBPIPCConnection: MainAppToDBPBackgroundAgentCommunication {

    var manager: DataBrokerProtectionBackgroundManager { DataBrokerProtectionBackgroundManager.shared // We really should change this
    }

    public func register(_ completionHandler: @escaping (Bool) -> Void) {
        os_log("App registered", log: .dbpBackgroundAgent, type: .debug)
        completionHandler(true)
        //App will then call appDidStart if appropriate
    }

    public func appDidStart() {
        manager.runOperationsAndStartSchedulerIfPossible()
    }

    public func profileModified() {
        manager.stopScheduler() // TODO what do we do if they edit, but don't press start scan?
    }

    public func startScanPressed() {
        manager.scheduler.stopScheduler()
        manager.scanAllBrokers() {
            self.brokersScanCompleted()
        }
        // TODO do we not need to start the scheduelr here?
    }

    // MARK: Debug features
    // Since they are debug features, we call the scheduler directly
    // rather than corrupting another interface

    public func startScheduler(showWebView: Bool) {
        manager.scheduler.startScheduler(showWebView: showWebView)
    }

    public func stopScheduler() {
        manager.scheduler.stopScheduler()
    }

    public func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        manager.scheduler.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        manager.scheduler.scanAllBrokers(showWebView: showWebView) {
            self.brokersScanCompleted()
            completion?()
        }
    }

    public func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) {
        manager.scheduler.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    public func runAllOperations(showWebView: Bool) {
        manager.scheduler.runAllOperations(showWebView: showWebView)
    }
}
 */

