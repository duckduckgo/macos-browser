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
import Common
import BrowserServicesKit
import Persistence
import Configuration
import Networking
import Bookmarks
import DDGSync
import ServiceManagement
import SyncDataProviders

#if NETWORK_PROTECTION
import NetworkProtection
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, FileDownloadManagerDelegate {

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

#if CI
    private let keyStore = (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
#else
    private let keyStore = EncryptionKeyStore()
#endif
    private var fileStore: FileStore!

    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    private let crashReporter = CrashReporter()
    private(set) var internalUserDecider: InternalUserDecider?
    private(set) var featureFlagger: FeatureFlagger!
    private var appIconChanger: AppIconChanger!

    private(set) var syncDataProviders: SyncDataProviders!
    private(set) var syncService: DDGSyncing?
    private var syncStateCancellable: AnyCancellable?
    private var bookmarksSyncErrorCancellable: AnyCancellable?
    let bookmarksManager = LocalBookmarkManager.shared

#if !APPSTORE
    var updateController: UpdateController!
#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    // swiftlint:disable:next function_body_length
    func applicationWillFinishLaunching(_ notification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        Configuration.setURLProvider(AppConfigurationURLProvider())

        if !NSApp.isRunningUnitTests {
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

            BookmarkDatabase.shared.db.loadStore { context, error in
                guard let context = context else {
                    if let error = error {
                        Pixel.fire(.debug(event: .bookmarksCouldNotLoadDatabase, error: error))
                    } else {
                        Pixel.fire(.debug(event: .bookmarksCouldNotLoadDatabase))
                    }

                    Thread.sleep(forTimeInterval: 1)
                    fatalError("Could not create Bookmarks database stack: \(error?.localizedDescription ?? "err")")
                }

                let legacyDB = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType)
                legacyDB.performAndWait {
                    LegacyBookmarksStoreMigration.setupAndMigrate(from: legacyDB,
                                                                  to: context)
                }
            }
        }

        do {
            let encryptionKey = NSApp.isRunningUnitTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        let internalUserDecider = DefaultInternalUserDecider(store: internalUserDeciderStore)
        self.internalUserDecider = internalUserDecider

#if DEBUG
        func mock<T>(_ className: String) -> T {
            ((NSClassFromString(className) as? NSObject.Type)!.init() as? T)!
        }
        AppPrivacyFeatures.shared = NSApp.isRunningUnitTests
            // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
            ? AppPrivacyFeatures(contentBlocking: mock("ContentBlockingMock"), httpsUpgradeStore: mock("HTTPSUpgradeStoreMock"))
            : AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider), database: Database.shared)
#else
        AppPrivacyFeatures.shared = AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider), database: Database.shared)
#endif

        featureFlagger = DefaultFeatureFlagger(internalUserDecider: internalUserDecider,
                                               privacyConfig: AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig)
        NSApp.mainMenuTyped.setup(with: featureFlagger)

#if !APPSTORE
        updateController = UpdateController(internalUserDecider: internalUserDecider)
        stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
#endif

        appIconChanger = AppIconChanger(internalUserDecider: internalUserDecider)

        syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db)
        syncService = DDGSync(dataProvidersSource: syncDataProviders, log: OSLog.sync)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !NSApp.isRunningUnitTests else { return }

        HistoryCoordinator.shared.loadHistory()
        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        bookmarksManager.loadBookmarks()
        FaviconManager.shared.loadFavicons()
        ConfigurationManager.shared.start()
        FileDownloadManager.shared.delegate = self
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        if LocalStatisticsStore().atb == nil {
            Pixel.firstLaunchDate = Date()
        }
        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        stateRestorationManager.applicationDidFinishLaunching()

        BWManager.shared.initCommunication()

        if WindowsManager.windows.isEmpty,
           case .normal = NSApp.runType {
            WindowsManager.openNewWindow(isBurner: false, lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

        crashReporter.checkForNewReports()

        urlEventHandler.applicationDidFinishLaunching()

        subscribeToEmailProtectionStatusNotifications()
        subscribeToDataImportCompleteNotification()

        UserDefaultsWrapper<Any>.clearRemovedKeys()

#if NETWORK_PROTECTION
        startupNetworkProtection()
#endif

        startupSync()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        syncService?.scheduler.notifyAppLifecycleEvent()
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

    func askUserToGrantAccessToDestination(_ folderUrl: URL) {
        if FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.lastPathComponent == folderUrl.lastPathComponent {
            let alert = NSAlert.noAccessToDownloads()
            if alert.runModal() != .cancel {
                guard let preferencesLink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_DownloadsFolder") else {
                    assertionFailure("Can't initialize preferences link")
                    return
                }
                NSWorkspace.shared.open(preferencesLink)
                return
            }
        } else {
            let alert = NSAlert.noAccessToSelectedFolder()
            alert.runModal()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if WindowControllersManager.shared.mainWindowControllers.isEmpty {
            WindowsManager.openNewWindow(isBurner: false)
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let internalUserDecider else {
            return nil
        }

        return ApplicationDockMenu(internalUserDecider: internalUserDecider)
    }

    func application(_ sender: NSApplication, openFiles files: [String]) {
        urlEventHandler.handleFiles(files)
    }

    private func applyPreferredTheme() {
        let appearancePreferences = AppearancePreferences()
        appearancePreferences.updateUserInterfaceStyle()
    }

    // MARK: - Sync

    private func startupSync() {
        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db)
        let syncService = DDGSync(dataProvidersSource: syncDataProviders, log: OSLog.sync)

        syncStateCancellable = syncService.authStatePublisher
            .prepend(syncService.authState)
            .map { $0 == .inactive }
            .removeDuplicates()
            .sink { isSyncDisabled in
                LocalBookmarkManager.shared.updateBookmarkDatabaseCleanupSchedule(shouldEnable: isSyncDisabled)
            }

        // This is also called in applicationDidBecomeActive, but we're also calling it here, since
        // syncService can be nil when applicationDidBecomeActive is called during startup, if a modal
        // alert is shown before it's instantiated.  In any case it should be safe to call this here,
        // since the scheduler debounces calls to notifyAppLifecycleEvent().
        //
        syncService.scheduler.notifyAppLifecycleEvent()

        self.syncDataProviders = syncDataProviders
        self.syncService = syncService
    }

    // MARK: - Network Protection

#if NETWORK_PROTECTION

    private func startupNetworkProtection() {
        let networkProtectionFeatureVisibility = NetworkProtectionKeychainTokenStore()

        guard networkProtectionFeatureVisibility.isFeatureActivated else {
            NetworkProtectionTunnelController.disableLoginItems()
            LocalPinningManager.shared.unpin(.networkProtection)
            return
        }

        updateNetworkProtectionIfVersionChanged()
        refreshNetworkProtectionServers()
    }

    private func updateNetworkProtectionIfVersionChanged() {
        let currentVersion = AppVersion.shared.versionNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        defer {
            versionStore.lastVersionRun = currentVersion
        }

        // should‘ve been run at least once with NetP enabled
        guard let lastVersionRun = versionStore.lastVersionRun else {
            os_log(.error, log: .networkProtection, "🔴 running netp for the first time: update not needed")
            return
        }

        if lastVersionRun != currentVersion {
            os_log(.error, log: .networkProtection, "🟡 App updated from %{public}s to %{public}s: updating", lastVersionRun, currentVersion)
            updateNetworkProtectionTunnelAndMenu()
        } else {
            // If login items failed to launch (e.g. because of the App bundle rename), launch using NSWorkspace
            NetworkProtectionTunnelController.ensureLoginItemsAreRunning(.ifLoginItemsAreEnabled, after: 1)
        }
    }

    private func updateNetworkProtectionTunnelAndMenu() {
        Task {
            let provider = NetworkProtectionTunnelController()

            if await provider.isConnected() {
                try? await provider.stop()
            }
        }

        NetworkProtectionTunnelController.resetLoginItems()
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

#endif

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

    private func subscribeToDataImportCompleteNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(dataImportCompleteNotification(_:)), name: .dataImportComplete, object: nil)
    }

    @objc private func emailDidSignInNotification(_ notification: Notification) {
        Pixel.fire(.emailEnabled)
        let repetition = Pixel.Event.Repetition(key: Pixel.Event.emailEnabledInitial.name)
        // Temporary pixel for first time user enables email protection
        if Pixel.isNewUser && repetition == .initial {
            Pixel.fire(.emailEnabledInitial)
        }
    }

    @objc private func emailDidSignOutNotification(_ notification: Notification) {
        Pixel.fire(.emailDisabled)
    }

    @objc private func dataImportCompleteNotification(_ notification: Notification) {
        // Temporary pixel for first time user import data
        let repetition = Pixel.Event.Repetition(key: Pixel.Event.importDataInitial.name)
        if Pixel.isNewUser && repetition == .initial {
            Pixel.fire(.importDataInitial)
        }
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
