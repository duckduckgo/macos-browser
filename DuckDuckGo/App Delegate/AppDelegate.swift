//
//  AppDelegate.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log
import BrowserServicesKit
import Persistence
import ServiceManagement
import NetworkProtection

final class AppDelegate: NSObject, NSApplicationDelegate {

#if DEBUG
    static var isRunningTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
#else
    static var isRunningTests: Bool { false }
#endif

#if DEBUG
    let disableCVDisplayLinkLogs: Void = {
        // Disable CVDisplayLink logs
        CFPreferencesSetValue("cv_note" as CFString,
                              0 as CFPropertyList,
                              "com.apple.corevideo" as CFString,
                              kCFPreferencesCurrentUser,
                              kCFPreferencesAnyHost)
        CFPreferencesSynchronize("com.apple.corevideo" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }()
#endif

    let urlEventHandler = URLEventHandler()

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!

    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    private let crashReporter = CrashReporter()
    private(set) var internalUserDecider: InternalUserDeciding!
    private var appIconChanger: AppIconChanger!

#if !APPSTORE
    var updateController: UpdateController!
#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if !Self.isRunningTests {
#if DEBUG
            Pixel.setUp(dryRun: true)
#else
            Pixel.setUp()
#endif

            Database.shared.loadStore { _, error in
                guard let error = error else { return }

                switch error {
                case CoreDataDatabase.Error.containerLocationCouldNotBePrepared(let underlyingError):
                    Pixel.fire(.debug(event: .dbContainerInitializationError, error: underlyingError))
                default:
                    Pixel.fire(.debug(event: .dbInitializationError, error: error))
                }

                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }
        }

#if DEBUG
        func mock<T>(_ className: String) -> T {
            ((NSClassFromString(className) as? NSObject.Type)!.init() as? T)!
        }
        AppPrivacyFeatures.shared = AppDelegate.isRunningTests
            // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
            ? AppPrivacyFeatures(contentBlocking: mock("ContentBlockingMock"), httpsUpgradeStore: mock("HTTPSUpgradeStoreMock"))
            : AppPrivacyFeatures(contentBlocking: AppContentBlocking(), httpsUpgradeStore: AppHTTPSUpgradeStore())
#else
        AppPrivacyFeatures.shared = AppPrivacyFeatures(contentBlocking: AppContentBlocking(),
                                                       httpsUpgradeStore: AppHTTPSUpgradeStore())
#endif

        do {
            let encryptionKey = Self.isRunningTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        internalUserDecider = InternalUserDecider(store: internalUserDeciderStore)

#if !APPSTORE
        updateController = UpdateController(internalUserDecider: internalUserDecider)
        stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
#endif

        appIconChanger = AppIconChanger(internalUserDecider: internalUserDecider)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        HistoryCoordinator.shared.loadHistory()
        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        LocalBookmarkManager.shared.loadBookmarks()
        FaviconManager.shared.loadFavicons()
        ConfigurationManager.shared.start()
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        stateRestorationManager.applicationDidFinishLaunching()

        BWManager.shared.initCommunication()

        if WindowsManager.windows.isEmpty {
            WindowsManager.openNewWindow(lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

        crashReporter.checkForNewReports()

        urlEventHandler.applicationDidFinishLaunching()

        subscribeToEmailProtectionStatusNotifications()

        UserDefaultsWrapper<Any>.clearRemovedKeys()

        startupNetworkProtection()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !FileDownloadManager.shared.downloads.isEmpty {
            let alert = NSAlert.activeDownloadsTerminationAlert(for: FileDownloadManager.shared.downloads)
            if alert.runModal() == .cancel {
                return .terminateCancel
            }
            FileDownloadManager.shared.cancelAll(waitUntilDone: true)
            DownloadListCoordinator.shared.sync()
        }
        stateRestorationManager?.applicationWillTerminate()

        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if WindowControllersManager.shared.mainWindowControllers.isEmpty {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return ApplicationDockMenu()
    }

    func application(_ sender: NSApplication, openFiles files: [String]) {
        urlEventHandler.handleFiles(files)
    }

    private func applyPreferredTheme() {
        let appearancePreferences = AppearancePreferences()
        appearancePreferences.updateUserInterfaceStyle()
    }

    // MARK: - Network Protection

    private func startupNetworkProtection() {
        updateNetworkProtectionIfVersionChanged()
        refreshNetworkProtectionServers()
        warnUserAboutApplicationPathForNetworkProtection()
    }

    private func updateNetworkProtectionIfVersionChanged() {
        let currentVersion = AppVersion.shared.versionNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        defer {
            versionStore.lastVersionRun = currentVersion
        }

        if let lastVersionRun = versionStore.lastVersionRun,
           lastVersionRun == currentVersion {

            return
        }

        updateNetworkProtectionTunnelAndMenu()
    }

    private func updateNetworkProtectionTunnelAndMenu() {
        Task {
            let provider = DefaultNetworkProtectionProvider()

            if await provider.isConnected() {
                try? await provider.stop()
            }
        }

        resetLoginItemsIfAlreadyRunning()
    }

    private func resetLoginItemsIfAlreadyRunning() {
        do {
            try LoginItem(identifier: .vpnMenu).reset()
        } catch {
            os_log("Failed to reset the vpnMenu login item: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
        }

        do {
            try LoginItem(identifier: .notificationsAgent).reset()
        } catch {
            os_log("Failed to reset the notificationsAgent login item: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
        }
    }

    /// Fetches a new list of Network Protection servers, and updates the existing set.
    private func refreshNetworkProtectionServers() {
        Task {
            let serverCount: Int
            do {
                serverCount = try await NetworkProtectionDeviceManager.create().refreshServerList().count
            } catch {
                os_log("Failed to update Network Protection servers", log: .networkProtection, type: .error)
                return
            }

            os_log("Successfully updated Network Protection servers; total server count = %{public}d", log: .networkProtection, serverCount)
        }
    }

    /// Warns the user if they're trying to run a NetP build outside of /Applications, but only if it's not a debug build.
    private func warnUserAboutApplicationPathForNetworkProtection() {
        #if NETP_SYSTEM_EXTENSION && !DEBUG
        let bundlePath = Bundle.main.bundlePath

        if !bundlePath.hasPrefix("/Applications/DuckDuckGo") {
            guard let window = WindowsManager.windows.first(where: { $0 is MainWindow }) else {
                assertionFailure("No window")
                return
            }

            let alert = NSAlert.networkProtectionBuildLocationWarning()
            alert.beginSheetModal(for: window)
        }
        #endif
    }

    private func subscribeToEmailProtectionStatusNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignInNotification(_:)),
                                               name: .emailDidSignIn,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignOutNotification(_:)),
                                               name: .emailDidSignOut,
                                               object: nil)
    }

    @objc private func emailDidSignInNotification(_ notification: Notification) {
        Pixel.fire(.emailEnabled)
    }

    @objc private func emailDidSignOutNotification(_ notification: Notification) {
        Pixel.fire(.emailDisabled)
    }
}

extension AppDelegate: AppUsageActivityMonitorDelegate {

    func countOpenWindowsAndTabs() -> [Int] {
        return WindowControllersManager.shared.mainWindowControllers
            .map { $0.mainViewController.tabCollectionViewModel.tabCollection.tabs.count }
    }

    func activeUsageTimeHasReachedThreshold(avgTabCount: Double) {
        // This is temporarily unused while we determine whether it required to determine an active user count.
    }

}
