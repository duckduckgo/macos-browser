//
//  DuckDuckGoDBPBackgroundAgentAppDelegate.swift
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
import PixelKit
import Networking
import Subscription

@objc(Application)
final class DuckDuckGoDBPBackgroundAgentApplication: NSApplication {
    private let _delegate: DuckDuckGoDBPBackgroundAgentAppDelegate
    private let subscriptionManager: SubscriptionManaging

    // swiftlint:disable:next function_body_length
    override init() {
        os_log(.error, log: .dbpBackgroundAgent, "🟢 DBP background Agent starting: %{public}d", NSRunningApplication.current.processIdentifier)

        let dryRun: Bool
#if DEBUG
        dryRun = true
#else
        dryRun = false
#endif

        PixelKit.setUp(dryRun: dryRun,
                       appVersion: AppVersion.shared.versionNumber,
                       source: "dbpBackgroundAgent",
                       defaultHeaders: [:],
                       defaults: .standard) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping (Bool, Error?) -> Void) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers) // workaround - Pixel class should really handle APIRequest.Headers by itself
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(true, error)
            }
        }

        let pixelHandler = DataBrokerProtectionPixelsHandler()
        pixelHandler.fire(.backgroundAgentStarted)

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            os_log(.error, log: .dbpBackgroundAgent, "🔴 Stopping: another instance is running: %{public}d.", anotherInstance.processIdentifier)
            pixelHandler.fire(.backgroundAgentStartedStoppingDueToAnotherInstanceRunning)
            exit(0)
        }

        // MARK: - Configure Subscription
        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = SubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
        let entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: subscriptionUserDefaults,
                                                                 key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                                 settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))
        let accessTokenStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
        let subscriptionService = SubscriptionService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let authService = AuthService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let accountManager = AccountManager(accessTokenStorage: accessTokenStorage,
                                        entitlementsCache: entitlementsCache,
                                        subscriptionService: subscriptionService,
                                        authService: authService)

        if #available(macOS 12.0, *) {
            let storePurchaseManager = StorePurchaseManager()
            subscriptionManager = SubscriptionManager(storePurchaseManager: storePurchaseManager,
                                                      accountManager: accountManager,
                                                      subscriptionService: subscriptionService,
                                                      authService: authService,
                                                      subscriptionEnvironment: subscriptionEnvironment)
        } else {
            subscriptionManager = SubscriptionManager(accountManager: accountManager,
                                                      subscriptionService: subscriptionService,
                                                      authService: authService,
                                                      subscriptionEnvironment: subscriptionEnvironment)
        }

        _delegate = DuckDuckGoDBPBackgroundAgentAppDelegate(subscriptionManager: subscriptionManager)

        super.init()
        self.delegate = _delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

@main
final class DuckDuckGoDBPBackgroundAgentAppDelegate: NSObject, NSApplicationDelegate {
    private let settings = DataBrokerProtectionSettings()
    private var cancellables = Set<AnyCancellable>()
    private var statusBarMenu: StatusBarMenu?
    private let subscriptionManager: SubscriptionManaging
    private let manager: DataBrokerProtectionBackgroundManager

    init(subscriptionManager: SubscriptionManaging) {
        self.subscriptionManager = subscriptionManager
        self.manager = DataBrokerProtectionBackgroundManager(subscriptionManager: subscriptionManager)
    }

    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("DuckDuckGoAgent started", log: .dbpBackgroundAgent, type: .info)

        manager.runOperationsAndStartSchedulerIfPossible()

        setupStatusBarMenu()

        // Update environment
        settings.alignTo(subscriptionEnvironment: subscriptionManager.currentEnvironment)
    }

    @MainActor
    private func setupStatusBarMenu() {
        statusBarMenu = StatusBarMenu()

        if settings.showInMenuBar {
            statusBarMenu?.show()
        } else {
            statusBarMenu?.hide()
        }

        settings.showInMenuBarPublisher.sink { [weak self] showInMenuBar in
            Task { @MainActor in
                if showInMenuBar {
                    self?.statusBarMenu?.show()
                } else {
                    self?.statusBarMenu?.hide()
                }
            }
        }.store(in: &cancellables)
    }
}
