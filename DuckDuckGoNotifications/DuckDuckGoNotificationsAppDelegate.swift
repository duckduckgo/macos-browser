//
//  DuckDuckGoNotificationsAppDelegate.swift
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
import os.log // swiftlint:disable:this enforce_os_log_wrapper
import NetworkExtension
import NetworkProtection

@objc(Application)
final class DuckDuckGoNotificationsApplication: NSApplication {
    private let _delegate = DuckDuckGoNotificationsAppDelegate()

    override init() {
        os_log(.error, log: .networkProtection, "🟢 Notifications Agent starting: %{public}d", ProcessInfo.processInfo.processIdentifier)

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            os_log(.error, log: .networkProtection, "🔴 Stopping: another instance is running: %{public}d.", anotherInstance.processIdentifier)
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
final class DuckDuckGoNotificationsAppDelegate: NSObject, NSApplicationDelegate {

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

#if NETP_SYSTEM_EXTENSION
    private let ipcConnection = IPCConnection(log: .networkProtectionIPCLoginItemLog, memoryManagementLog: .networkProtectionMemoryLog)
#endif

    private let distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)

    // MARK: - Notifications: Observation Tokens

    private var observationTokens = [NotificationToken]()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("Login item finished launching", log: .networkProtectionLoginItemLog, type: .info)

        startObservingVPNStatusChanges()
        registerConnection(listenerStarted: false)
        os_log("Login item listening")
    }

    private func startObservingVPNStatusChanges() {
        os_log("Register with sysex")

        observationTokens.append(distributedNotificationCenter.addObserver(for: .ipcListenerStarted, object: nil, queue: .main) { [weak self] _ in

            os_log("Got notification: listener started")
            self?.registerConnection(listenerStarted: true)
        })

        observationTokens.append(distributedNotificationCenter.addObserver(for: .serverSelected, object: nil, queue: nil) { [weak self] _ in

            os_log("Got notification: listener started")
            self?.notificationsPresenter.requestAuthorization()
        })
    }

    private var machServiceName: String {
        let agentBundleIDInfoPlistKey = "SYSEX_MACH_SERVICE_NAME"

        guard let agentBundleID = Bundle.main.object(forInfoDictionaryKey: agentBundleIDInfoPlistKey) as? String else {
            fatalError("Please make sure that this target has key \(agentBundleIDInfoPlistKey) in its Info.plist file.")
        }

        return agentBundleID
    }

    /// Registers an IPC connection with the system extension
    ///
    /// - Parameters:
    ///     - listenerStarted: this should be true if the registration request comes as the result of us learning that the IPC service has been
    ///         started by the system extension.  This is purely for more precise logging.
    ///
    private func registerConnection(listenerStarted: Bool) {
#if NETP_SYSTEM_EXTENSION
        ipcConnection.register(machServiceName: machServiceName, delegate: self) { success in
            DispatchQueue.main.async {
                if success {
                    os_log("IPC connection with system extension succeeded")
                } else {
                    os_log("IPC connection with system extension failed")

                    if listenerStarted {
                        os_log("IPC connection should have succeeded")
                    }
                }
            }
        }
#endif
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

#if NETP_SYSTEM_EXTENSION
extension DuckDuckGoNotificationsAppDelegate: AppCommunication {

    func reconnected() {
        os_log("Presenting reconnected notification", log: .networkProtection, type: .info)
        notificationsPresenter.showReconnectedNotification()
    }

    func reconnecting() {
        os_log("Presenting reconnecting notification", log: .networkProtection, type: .info)
        notificationsPresenter.showReconnectingNotification()
    }

    func connectionFailure() {
        os_log("Presenting failure notification", log: .networkProtection, type: .info)
        notificationsPresenter.showConnectionFailureNotification()
    }

    func statusChanged(status: NEVPNStatus) {
        os_log("Status changed", log: .networkProtection, type: .info)
    }
}
#endif
