//
//  AppDelegate.swift
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
import os
import NetworkExtension

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let notificationsPresenter = {
        let parentBundlePath = "../../../../"
        let mainAppURL: URL

        if #available(macOS 13, *) {
            mainAppURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            mainAppURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        return NetworkProtectionUNNotificationsPresenter(mainAppURL: mainAppURL)
    }()
    private var statusChangeObserverToken: NSObjectProtocol?
    private let ipcConnection = IPCConnection(log: .networkProtectionIPCLoginItemLog, memoryManagementLog: .networkProtectionMemoryLog)

    var observer: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("Login item running")

        startObservingVPNStatusChanges()
        registerConnection(listenerStarted: false)
        os_log("Login item listening")
    }

    private func startObservingVPNStatusChanges() {
        os_log("Register with sysex")

        DistributedNotificationCenter.forType(.networkProtection).addObserver(forName: .NetPIPCListenerStarted, object: nil, queue: .main) { [weak self] _ in

            os_log("Got notification: listener started")
            self?.registerConnection(listenerStarted: true)
        }

        DistributedNotificationCenter.forType(.networkProtection).addObserver(forName: .NetPServerSelected, object: nil, queue: nil) { [weak self] _ in

            os_log("Got notification: listener started")
            self?.notificationsPresenter.requestAuthorization()
        }
    }

    /// Registers an IPC connection with the system extension
    ///
    /// - Parameters:
    ///     - listenerStarted: this should be true if the registration request comes as the result of us learning that the IPC service has been
    ///         started by the system extension.  This is purely for more precise logging.
    ///
    private func registerConnection(listenerStarted: Bool) {
        ipcConnection.register(machServiceName: "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension", delegate: self) { success in
            DispatchQueue.main.async {
                if success {
                    os_log("IPC connection with system extension succeeded")
                } else {
                    os_log("IPC connection with system extension failed")

                    if listenerStarted {
                        // - TODO: maybe worth making this a pixel, as we just received a notification that IPC is up
                        os_log("IPC connection should have succeeded")
                    }
                }
            }
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: AppCommunication {
    func reconnected() {
        os_log("Presenting reconnected notification")
        notificationsPresenter.showReconnectedNotification()
    }

    func reconnecting() {
        os_log("Presenting reconnecting notification")
        notificationsPresenter.showReconnectingNotification()
    }

    func connectionFailure() {
        os_log("Presenting failure notification")
        notificationsPresenter.showConnectionFailureNotification()
    }
}
