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

import AppLauncher
import Cocoa
import Combine
import NetworkExtension
import NetworkProtection
import VPNAppLauncher
import os.log

@objc(Application)
final class DuckDuckGoNotificationsApplication: NSApplication {
    private let _delegate = DuckDuckGoNotificationsAppDelegate()

    override init() {
        Logger.networkProtection.log("🟢 Notifications Agent init: \(ProcessInfo.processInfo.processIdentifier, privacy: .public)")

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            Logger.networkProtection.error("Stopping: another instance is running: \(anotherInstance.processIdentifier, privacy: .public).")
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
        Logger.networkProtection.info("Login item finished launching")

        startObservingVPNStatusChanges()
        Logger.networkProtection.log("Login item listening")
    }

    private func startObservingVPNStatusChanges() {
        Logger.networkProtection.log("Register with sysex")

        distributedNotificationCenter.publisher(for: .showIssuesStartedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showReconnectingNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showConnectedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let serverLocation = notification.object as? String
                self?.showConnectedNotification(serverLocation: serverLocation)
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showIssuesNotResolvedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showConnectionFailureNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showVPNSupersededNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showSupersededNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showTestNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showTestNotification()
            }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .serverSelected).sink { [weak self] _ in
            Logger.networkProtection.log("Got notification: listener started")
            self?.notificationsPresenter.requestAuthorization()
        }.store(in: &cancellables)

        distributedNotificationCenter.publisher(for: .showExpiredEntitlementNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showEntitlementNotification()
            }.store(in: &cancellables)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Showing Notifications

    func showConnectedNotification(serverLocation: String?) {
        Logger.networkProtection.info("Presenting reconnected notification")
        notificationsPresenter.showConnectedNotification(serverLocation: serverLocation, snoozeEnded: false)
    }

    func showReconnectingNotification() {
        Logger.networkProtection.info("Presenting reconnecting notification")
        notificationsPresenter.showReconnectingNotification()
    }

    func showConnectionFailureNotification() {
        Logger.networkProtection.info("Presenting failure notification")
        notificationsPresenter.showConnectionFailureNotification()
    }

    func showSupersededNotification() {
        Logger.networkProtection.info("Presenting Superseded notification")
        notificationsPresenter.showSupersededNotification()
    }

    func showEntitlementNotification() {
        Logger.networkProtection.info("Presenting Entitlements notification")

        notificationsPresenter.showEntitlementNotification()
    }

    func showTestNotification() {
        Logger.networkProtection.info("Presenting test notification")
        notificationsPresenter.showTestNotification()
    }

}
