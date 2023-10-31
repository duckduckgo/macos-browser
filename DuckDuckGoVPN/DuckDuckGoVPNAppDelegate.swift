//
//  DuckDuckGoVPNAppDelegate.swift
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
import Networking
import NetworkExtension
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import ServiceManagement
import PixelKit

@objc(Application)
final class DuckDuckGoVPNApplication: NSApplication {
    private let _delegate = DuckDuckGoVPNAppDelegate()

    override init() {
        os_log(.error, log: .networkProtection, "🟢 Status Bar Agent starting: %{public}d", NSRunningApplication.current.processIdentifier)

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
final class DuckDuckGoVPNAppDelegate: NSObject, NSApplicationDelegate {

    private static let recentThreshold: TimeInterval = 5.0

    private let appLauncher = AppLauncher()
    private let bouncer = NetworkProtectionBouncer()

    var networkExtensionBundleID: String {
        Bundle.main.networkExtensionBundleID
    }

#if NETP_SYSTEM_EXTENSION
    private lazy var networkExtensionController = NetworkExtensionController(extensionBundleID: networkExtensionBundleID)
#endif

    private lazy var tunnelController = NetworkProtectionTunnelController(
        networkExtensionBundleID: networkExtensionBundleID,
        networkExtensionController: networkExtensionController,
        settings: .init(defaults: .shared))

    /// An IPC server that provides access to the tunnel controller.
    ///
    /// This is used by our main app to control the tunnel through the VPN login item.
    ///
    private lazy var tunnelControllerIPCService: TunnelControllerIPCService = {
        let ipcServer = TunnelControllerIPCService(
            tunnelController: tunnelController,
            networkExtensionController: networkExtensionController,
            statusReporter: statusReporter)
        ipcServer.activate()
        return ipcServer
    }()

    private lazy var statusReporter: NetworkProtectionStatusReporter = {
        let errorObserver = ConnectionErrorObserverThroughSession(
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        let statusObserver = ConnectionStatusObserverThroughSession(
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        let serverInfoObserver = ConnectionServerInfoObserverThroughSession(
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        return DefaultNetworkProtectionStatusReporter(
            statusObserver: statusObserver,
            serverInfoObserver: serverInfoObserver,
            connectionErrorObserver: errorObserver,
            connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
            controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
        )
    }()

    /// The status bar NetworkProtection menu
    ///
    /// For some reason the App will crash if this is initialized right away, which is why it was changed to be lazy.
    ///
    @MainActor
    private lazy var networkProtectionMenu: StatusBarMenu = {
        #if DEBUG
        let iconProvider = DebugMenuIconProvider()
        #elseif REVIEW
        let iconProvider = ReviewMenuIconProvider()
        #else
        let iconProvider = MenuIconProvider()
        #endif

        let menuItems = [
            StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuShareFeedback, action: { [weak self] in
                await self?.appLauncher.launchApp(withCommand: .shareFeedback)
            }),
            StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuOpenDuckDuckGo, action: { [weak self] in
                await self?.appLauncher.launchApp(withCommand: .justOpen)
            })
        ]

        let onboardingStatusPublisher = UserDefaults.shared.publisher(for: \.networkProtectionOnboardingStatusRawValue).map { rawValue in
            OnboardingStatus(rawValue: rawValue) ?? .default
        }.eraseToAnyPublisher()

        return StatusBarMenu(
            onboardingStatusPublisher: onboardingStatusPublisher,
            statusReporter: statusReporter,
            controller: tunnelController,
            iconProvider: iconProvider,
            menuItems: menuItems)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())

        os_log("DuckDuckGoVPN started", log: .networkProtectionLoginItemLog, type: .info)
        networkProtectionMenu.show()

        bouncer.requireAuthTokenOrKillApp()

        // Initialize the IPC server
        _ = tunnelControllerIPCService

        PixelKit.setUp(dryRun: false, appVersion: AppVersion.shared.versionNumber, defaultHeaders: [:], log: .networkProtectionPixel) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping (Error?) -> Void) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers) // workaround - Pixel class should really handle APIRequest.Headers by itself
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error)
            }
        }
    }
}

extension NSApplication {

    enum RunType: Int, CustomStringConvertible {
        case normal
        var description: String {
            switch self {
            case .normal: return "normal"
            }
        }
    }
    static var runType: RunType { .normal }

}
