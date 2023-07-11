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
import Combine
import Common
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
            exit(EXIT_SUCCESS)
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

        return NetworkProtectionUNNotificationsPresenter(appLauncher: AppLauncher(appBundleURL: mainAppURL))
    }()

    private let distributedNotificationCenter = DistributedNotificationCenter.default()

    // MARK: - Notifications: Observation Tokens

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("Login item finished launching", log: .networkProtectionLoginItemLog, type: .info)

        startObservingVPNStatusChanges()
        os_log("Login item listening")
    }

    private func startObservingVPNStatusChanges() {
        os_log("Register with sysex")

        distributedNotificationCenter.publisher(for: .showIssuesStartedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notificationsPresenter.showReconnectingNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showIssuesResolvedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notificationsPresenter.showReconnectedNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showIssuesNotResolvedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notificationsPresenter.showConnectionFailureNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showVPNSupersededNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notificationsPresenter.showSupersededNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .serverSelected).sink { [weak self] _ in
            os_log("Got notification: listener started")
            self?.notificationsPresenter.requestAuthorization()
        }.store(in: &cancellables)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
