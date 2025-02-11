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

import AppLauncher
import BrowserServicesKit
import Cocoa
import Combine
import Common
import Configuration
import FeatureFlags
import LoginItems
import Networking
import NetworkExtension
import NetworkProtection
import NetworkProtectionProxy
import NetworkProtectionUI
import os.log
import PixelKit
import ServiceManagement
import Subscription
import SwiftUICore
import VPNAppLauncher

@objc(Application)
final class DuckDuckGoVPNApplication: NSApplication {

    public var accountManager: AccountManager
    private let _delegate: DuckDuckGoVPNAppDelegate

    override init() {
        Logger.networkProtection.log("🟢 Status Bar Agent starting\nPath: (\(Bundle.main.bundlePath, privacy: .public))\nVersion: \("\(Bundle.main.versionNumber!).\(Bundle.main.buildNumber)", privacy: .public)\nPID: \(NSRunningApplication.current.processIdentifier, privacy: .public)")

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            Logger.networkProtection.error("Stopping: another instance is running: \(anotherInstance.processIdentifier, privacy: .public).")
            exit(0)
        }

        // MARK: - Configure Subscription
        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
        let subscriptionEndpointService = DefaultSubscriptionEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let authEndpointService = DefaultAuthEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: subscriptionUserDefaults,
                                                                 key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                                 settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))
        let accessTokenStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
        accountManager = DefaultAccountManager(accessTokenStorage: accessTokenStorage,
                                               entitlementsCache: entitlementsCache,
                                               subscriptionEndpointService: subscriptionEndpointService,
                                               authEndpointService: authEndpointService)

        _delegate = DuckDuckGoVPNAppDelegate(accountManager: accountManager,
                                             accessTokenStorage: accessTokenStorage,
                                             subscriptionEnvironment: subscriptionEnvironment)
        super.init()

        setupPixelKit()
        self.delegate = _delegate
        accountManager.delegate = _delegate

#if DEBUG
        if accountManager.accessToken != nil {
            Logger.networkProtection.error("🟢 VPN Agent found token")
        } else {
            Logger.networkProtection.error("VPN Agent found no token")
        }
#endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func setupPixelKit() {
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
    }
}

@main
final class DuckDuckGoVPNAppDelegate: NSObject, NSApplicationDelegate {

    private static let recentThreshold: TimeInterval = 5.0

    private let appLauncher = AppLauncher()
    private let accountManager: AccountManager
    private let accessTokenStorage: SubscriptionTokenKeychainStorage

    private let configurationStore = ConfigurationStore()
    private let configurationManager: ConfigurationManager
    private var configurationSubscription: AnyCancellable?
    private let privacyConfigurationManager = VPNPrivacyConfigurationManager(internalUserDecider: DefaultInternalUserDecider(store: UserDefaults.appConfiguration))
    private lazy var featureFlagger = DefaultFeatureFlagger(
        internalUserDecider: privacyConfigurationManager.internalUserDecider,
        privacyConfigManager: privacyConfigurationManager,
        localOverrides: FeatureFlagLocalOverrides(
            keyValueStore: UserDefaults.appConfiguration,
            actionHandler: FeatureFlagOverridesPublishingHandler<FeatureFlag>()
        ),
        experimentManager: nil,
        for: FeatureFlag.self)

    public init(accountManager: AccountManager,
                accessTokenStorage: SubscriptionTokenKeychainStorage,
                subscriptionEnvironment: SubscriptionEnvironment) {

        self.accountManager = accountManager
        self.accessTokenStorage = accessTokenStorage
        self.tunnelSettings = VPNSettings(defaults: .netP)
        self.tunnelSettings.alignTo(subscriptionEnvironment: subscriptionEnvironment)
        self.configurationManager = ConfigurationManager(privacyConfigManager: privacyConfigurationManager, store: configurationStore)
    }

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

    private let tunnelSettings: VPNSettings
    private lazy var userDefaults = UserDefaults.netP
    private lazy var proxySettings: TransparentProxySettings = {
        let settings = TransparentProxySettings(defaults: .netP)

#if APPSTORE
        settings.proxyAvailable = false
#else
        settings.proxyAvailable = true
#endif

        return settings
    }()

    @MainActor
    private lazy var vpnProxyLauncher = VPNProxyLauncher(
        tunnelController: tunnelController,
        proxyController: proxyController)

    @MainActor
    private lazy var proxyController: TransparentProxyController = {
        let eventHandler = TransparentProxyControllerEventHandler(logger: .transparentProxyLogger)

        let controller = TransparentProxyController(
            extensionID: proxyExtensionBundleID,
            storeSettingsInProviderConfiguration: storeProxySettingsInProviderConfiguration,
            settings: proxySettings,
            eventHandler: eventHandler) { [weak self] manager in
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

        return controller
    }()

    @MainActor
    private lazy var tunnelController = NetworkProtectionTunnelController(
        networkExtensionBundleID: tunnelExtensionBundleID,
        networkExtensionController: networkExtensionController,
        featureFlagger: featureFlagger,
        settings: tunnelSettings,
        defaults: userDefaults,
        accessTokenStorage: accessTokenStorage)

    /// An IPC server that provides access to the tunnel controller.
    ///
    /// This is used by our main app to control the tunnel through the VPN login item.
    ///
    @MainActor
    private lazy var tunnelControllerIPCService: TunnelControllerIPCService = {
        let ipcServer = TunnelControllerIPCService(
            tunnelController: tunnelController,
            uninstaller: vpnUninstaller,
            networkExtensionController: networkExtensionController,
            statusReporter: statusReporter)
        ipcServer.activate()
        return ipcServer
    }()

    @MainActor
    private lazy var statusObserver = ConnectionStatusObserverThroughSession(
        tunnelSessionProvider: tunnelController,
        platformSnoozeTimingStore: NetworkProtectionSnoozeTimingStore(userDefaults: .netP),
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

    @MainActor
    private lazy var vpnUninstaller: VPNUninstaller = {
        VPNUninstaller(
            tunnelController: tunnelController,
            networkExtensionController: networkExtensionController)
    }()

    /// The status bar NetworkProtection menu
    ///
    /// For some reason the App will crash if this is initialized right away, which is why it was changed to be lazy.
    ///
    @MainActor
    private lazy var networkProtectionMenu: StatusBarMenu = {
        makeStatusBarMenu()
    }()

    private func statusViewSubmenu() -> [StatusBarMenu.MenuItem] {
        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
        let proxySettings = TransparentProxySettings(defaults: .netP)

        var menuItems = [StatusBarMenu.MenuItem]()

        if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
            menuItems.append(
                .text(icon: Image(.settings16), title: UserText.vpnStatusViewVPNSettingsMenuItemTitle, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
                }))
        }

        menuItems.append(contentsOf: [
            .textWithDetail(
                icon: Image(.window16),
                title: UserText.vpnStatusViewExcludedAppsMenuItemTitle,
                detail: "(\(proxySettings.excludedApps.count))",
                action: { [weak self] in

                    try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.manageExcludedApps)
            }),
            .textWithDetail(
                icon: Image(.globe16),
                title: UserText.vpnStatusViewExcludedDomainsMenuItemTitle,
                detail: "(\(proxySettings.excludedDomains.count))",
                action: { [weak self] in

                    try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.manageExcludedDomains)
            }),
            .divider(),
            .text(icon: Image(.help16), title: UserText.vpnStatusViewFAQMenuItemTitle, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
            }),
            .text(icon: Image(.support16), title: UserText.vpnStatusViewSendFeedbackMenuItemTitle, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
            })
        ])

        return menuItems
    }

    private func legacyStatusViewSubmenu() -> [StatusBarMenu.MenuItem] {
        [
            .text(title: UserText.networkProtectionStatusMenuVPNSettings, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
            }),
            .text(title: UserText.networkProtectionStatusMenuFAQ, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
            }),
            .text(title: UserText.networkProtectionStatusMenuSendFeedback, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
            }),
            .text(title: UserText.networkProtectionStatusMenuOpenDuckDuckGo, action: { [weak self] in
                try? await self?.appLauncher.launchApp(withCommand: VPNAppLaunchCommand.justOpen)
            }),
        ]
    }

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
        let uiActionHandler = VPNUIActionHandler(
            appLauncher: appLauncher,
            proxySettings: proxySettings)

        return StatusBarMenu(
            model: model,
            onboardingStatusPublisher: onboardingStatusPublisher,
            statusReporter: statusReporter,
            controller: tunnelController,
            iconProvider: iconProvider,
            uiActionHandler: uiActionHandler,
            menuItems: { [weak self] in
                guard let self else { return [] }

                guard featureFlagger.isFeatureOn(.networkProtectionAppExclusions) else {
                    return legacyStatusViewSubmenu()
                }

                return statusViewSubmenu()
            },
            agentLoginItem: nil,
            isMenuBarStatusView: true,
            userDefaults: .netP,
            locationFormatter: DefaultVPNLocationFormatter(),
            uninstallHandler: { [weak self] in
                guard let self else { return }

                do {
                    try await self.vpnUninstaller.uninstall(includingSystemExtension: true)
                    exit(EXIT_SUCCESS)
                } catch {
                    // Intentional no-op: we already anonymously track VPN uninstallation failures using
                    // pixels within the vpn uninstaller.
                }
            }
        )
    }

    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        Logger.networkProtection.log("DuckDuckGoVPN started")

        // Setup Remote Configuration
        Configuration.setURLProvider(VPNAgentConfigurationURLProvider())
        configurationManager.start()
        // Load cached config (if any)
        privacyConfigurationManager.reload(etag: configurationStore.loadEtag(for: .privacyConfiguration), data: configurationStore.loadData(for: .privacyConfiguration))

        // It's important for this to be set-up after the privacy configuration is loaded
        // as it relies on it for the remote feature flag.
        TipKitAppEventHandler(featureFlagger: featureFlagger).appDidFinishLaunching()

        setupMenuVisibility()

        Task { @MainActor in
            // Initialize lazy properties
            _ = tunnelControllerIPCService
            _ = vpnProxyLauncher

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
        guard accountManager.isUserAuthenticated else { return }

        let entitlementsCheck = {
            await self.accountManager.hasEntitlement(forProductName: .networkProtection, cachePolicy: .reloadIgnoringLocalCacheData)
        }

        Task {
            await entitlementMonitor.start(entitlementCheck: entitlementsCheck) { [weak self] result in
                switch result {
                case .validEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = false
                case .invalidEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = true

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

extension DuckDuckGoVPNAppDelegate: AccountManagerKeychainAccessDelegate {

    public func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError) {
        PixelKit.fire(PrivacyProErrorPixel.privacyProKeychainAccessError(accessType: accessType, accessError: error),
                      frequency: .legacyDailyAndCount)
    }
}
