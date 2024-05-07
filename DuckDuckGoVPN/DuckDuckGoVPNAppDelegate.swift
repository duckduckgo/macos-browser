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
import LoginItems
import Networking
import NetworkExtension
import NetworkProtection
import NetworkProtectionProxy
import NetworkProtectionUI
import ServiceManagement
import PixelKit
import Subscription

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

#if DEBUG
        let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))

        if let token = accountManager.accessToken {
            os_log(.error, log: .networkProtection, "🟢 VPN Agent found token: %{public}d", token)
        } else {
            os_log(.error, log: .networkProtection, "🔴 VPN Agent found no token")
        }
#endif
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

    private var cancellables = Set<AnyCancellable>()

    var proxyExtensionBundleID: String {
        Bundle.proxyExtensionBundleID
    }

    var tunnelExtensionBundleID: String {
        Bundle.tunnelExtensionBundleID
    }

    private lazy var networkExtensionController = NetworkExtensionController(extensionBundleID: tunnelExtensionBundleID)

    private var storeProxySettingsInProviderConfiguration: Bool {
#if NETP_SYSTEM_EXTENSION
        true
#else
        false
#endif
    }

    private lazy var tunnelSettings = VPNSettings(defaults: .netP)
    private lazy var userDefaults = UserDefaults.netP
    private lazy var proxySettings = TransparentProxySettings(defaults: .netP)

    @MainActor
    private lazy var vpnProxyLauncher = VPNProxyLauncher(
        tunnelController: tunnelController,
        proxyController: proxyController)

    @MainActor
    private lazy var proxyController: TransparentProxyController = {
        let controller = TransparentProxyController(
            extensionID: proxyExtensionBundleID,
            storeSettingsInProviderConfiguration: storeProxySettingsInProviderConfiguration,
            settings: proxySettings) { [weak self] manager in
                guard let self else { return }

                manager.localizedDescription = "DuckDuckGo VPN Proxy"

                if !manager.isEnabled {
                    manager.isEnabled = true
                }

                manager.protocolConfiguration = {
                    let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
                    protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
                    protocolConfiguration.providerBundleIdentifier = self.proxyExtensionBundleID

                    // always-on
                    protocolConfiguration.disconnectOnSleep = false

                    // kill switch
                    // protocolConfiguration.enforceRoutes = false

                    // this setting breaks Connection Tester
                    // protocolConfiguration.includeAllNetworks = settings.includeAllNetworks

                    // This is intentionally not used but left here for documentation purposes.
                    // The reason for this is that we want to have full control of the routes that
                    // are excluded, so instead of using this setting we're just configuring the
                    // excluded routes through our VPNSettings class, which our extension reads directly.
                    // protocolConfiguration.excludeLocalNetworks = settings.excludeLocalNetworks

                    return protocolConfiguration
                }()
            }

        controller.eventHandler = handleControllerEvent(_:)

        return controller
    }()

    private func handleControllerEvent(_ event: TransparentProxyController.Event) {

    }

    @MainActor
    private lazy var tunnelController = NetworkProtectionTunnelController(
        networkExtensionBundleID: tunnelExtensionBundleID,
        networkExtensionController: networkExtensionController,
        settings: tunnelSettings,
        defaults: userDefaults)

    /// An IPC server that provides access to the tunnel controller.
    ///
    /// This is used by our main app to control the tunnel through the VPN login item.
    ///
    @MainActor
    private lazy var tunnelControllerIPCService: TunnelControllerIPCService = {
        let ipcServer = TunnelControllerIPCService(
            tunnelController: tunnelController,
            networkExtensionController: networkExtensionController,
            statusReporter: statusReporter)
        ipcServer.activate()
        return ipcServer
    }()

    @MainActor
    private lazy var statusObserver = ConnectionStatusObserverThroughSession(
        tunnelSessionProvider: tunnelController,
        platformNotificationCenter: NSWorkspace.shared.notificationCenter,
        platformDidWakeNotification: NSWorkspace.didWakeNotification)

    @MainActor
    private lazy var statusReporter: NetworkProtectionStatusReporter = {
        let errorObserver = ConnectionErrorObserverThroughSession(
            tunnelSessionProvider: tunnelController,
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        let serverInfoObserver = ConnectionServerInfoObserverThroughSession(
            tunnelSessionProvider: tunnelController,
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        let dataVolumeObserver = DataVolumeObserverThroughSession(
            tunnelSessionProvider: tunnelController,
            platformNotificationCenter: NSWorkspace.shared.notificationCenter,
            platformDidWakeNotification: NSWorkspace.didWakeNotification)

        return DefaultNetworkProtectionStatusReporter(
            statusObserver: statusObserver,
            serverInfoObserver: serverInfoObserver,
            connectionErrorObserver: errorObserver,
            connectivityIssuesObserver: DisabledConnectivityIssueObserver(),
            controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications(),
            dataVolumeObserver: dataVolumeObserver,
            knownFailureObserver: KnownFailureObserverThroughDistributedNotifications()
        )
    }()

    @MainActor
    private lazy var vpnAppEventsHandler = {
        VPNAppEventsHandler(tunnelController: tunnelController)
    }()

    private lazy var vpnUninstaller: VPNUninstaller = {
        VPNUninstaller(networkExtensionController: networkExtensionController, vpnConfigurationManager: VPNConfigurationManager())
    }()

    /// The status bar NetworkProtection menu
    ///
    /// For some reason the App will crash if this is initialized right away, which is why it was changed to be lazy.
    ///
    @MainActor
    private lazy var networkProtectionMenu: StatusBarMenu = {
        makeStatusBarMenu()
    }()

    @MainActor
    private func makeStatusBarMenu() -> StatusBarMenu {
        #if DEBUG
        let iconProvider = DebugMenuIconProvider()
        #elseif REVIEW
        let iconProvider = ReviewMenuIconProvider()
        #else
        let iconProvider = MenuIconProvider()
        #endif

        let onboardingStatusPublisher = UserDefaults.netP.publisher(for: \.networkProtectionOnboardingStatusRawValue).map { rawValue in
            OnboardingStatus(rawValue: rawValue) ?? .default
        }.eraseToAnyPublisher()

        let model = StatusBarMenuModel(vpnSettings: .init(defaults: .netP))

        return StatusBarMenu(
            model: model,
            onboardingStatusPublisher: onboardingStatusPublisher,
            statusReporter: statusReporter,
            controller: tunnelController,
            iconProvider: iconProvider,
            appLauncher: appLauncher,
            menuItems: {
                [
                    StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuVPNSettings, action: { [weak self] in
                        await self?.appLauncher.launchApp(withCommand: .showSettings)
                    }),
                    StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuFAQ, action: { [weak self] in
                        await self?.appLauncher.launchApp(withCommand: .showFAQ)
                    }),
                    StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuShareFeedback, action: { [weak self] in
                        await self?.appLauncher.launchApp(withCommand: .shareFeedback)
                    }),
                    StatusBarMenu.MenuItem(name: UserText.networkProtectionStatusMenuOpenDuckDuckGo, action: { [weak self] in
                        await self?.appLauncher.launchApp(withCommand: .justOpen)
                    }),
                ]
            },
            agentLoginItem: nil,
            isMenuBarStatusView: true,
            userDefaults: .netP,
            locationFormatter: DefaultVPNLocationFormatter(),
            uninstallHandler: { [weak self] in
                guard let self else { return }
                await self.vpnUninstaller.uninstall(includingSystemExtension: true)
            }
        )
    }

    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        SubscriptionPurchaseEnvironment.currentServiceEnvironment = tunnelSettings.selectedEnvironment == .production ? .production : .staging

        os_log("DuckDuckGoVPN started", log: .networkProtectionLoginItemLog, type: .info)

        setupMenuVisibility()

        Task { @MainActor in
            // The reason we want to await for this is that nothing else should be executed
            // if the app should quit.
            await bouncer.requireAuthTokenOrKillApp(controller: tunnelController)

            // Initialize lazy properties
            _ = tunnelControllerIPCService
            _ = vpnProxyLauncher

            let dryRun: Bool

#if DEBUG
            dryRun = true
#else
            dryRun = false
#endif

            let pixelSource: String

#if NETP_SYSTEM_EXTENSION
            pixelSource = "vpnAgent"
#else
            pixelSource = "vpnAgentAppStore"
#endif

            PixelKit.setUp(dryRun: dryRun,
                           appVersion: AppVersion.shared.versionNumber,
                           source: pixelSource,
                           defaultHeaders: [:],
                           defaults: .netP) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping PixelKit.CompletionBlock) in

                let url = URL.pixelUrl(forPixelNamed: pixelName)
                let apiHeaders = APIRequest.Headers(additionalHeaders: headers) // workaround - Pixel class should really handle APIRequest.Headers by itself
                let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
                let request = APIRequest(configuration: configuration)

                request.fetch { _, error in
                    onComplete(error == nil, error)
                }
            }

            vpnAppEventsHandler.appDidFinishLaunching()

            let launchInformation = LoginItemLaunchInformation(agentBundleID: Bundle.main.bundleIdentifier!, defaults: .netP)
            let launchedOnStartup = launchInformation.wasLaunchedByStartup
            launchInformation.update()

            setUpSubscriptionMonitoring()

            if launchedOnStartup {
                Task {
                    let isConnected = await tunnelController.isConnected

                    if !isConnected && tunnelSettings.connectOnLogin {
                        await tunnelController.start()
                    }
                }
            }
        }
    }

    @MainActor
    private func setupMenuVisibility() {
        if tunnelSettings.showInMenuBar {
            networkProtectionMenu.show()
        } else {
            networkProtectionMenu.hide()
        }

        tunnelSettings.showInMenuBarPublisher.sink { [weak self] showInMenuBar in
            Task { @MainActor in
                if showInMenuBar {
                    self?.networkProtectionMenu.show()
                } else {
                    self?.networkProtectionMenu.hide()
                }
            }
        }.store(in: &cancellables)
    }

    private lazy var entitlementMonitor = NetworkProtectionEntitlementMonitor()

    private func setUpSubscriptionMonitoring() {
        let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
        guard accountManager.isUserAuthenticated else { return }
        let entitlementsCheck = {
            await accountManager.hasEntitlement(for: .networkProtection, cachePolicy: .reloadIgnoringLocalCacheData)
        }

        Task {
            await entitlementMonitor.start(entitlementCheck: entitlementsCheck) { [weak self] result in
                switch result {
                case .validEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = false
                case .invalidEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = true
                    PixelKit.fire(VPNPrivacyProPixel.vpnAccessRevokedDialogShown, frequency: .dailyAndCount)

                    guard let self else { return }
                    Task {
                        let isConnected = await self.tunnelController.isConnected
                        if isConnected {
                            await self.tunnelController.stop()
                            DistributedNotificationCenter.default().post(.showExpiredEntitlementNotification)
                        }
                    }
                case .error:
                    break
                }
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
