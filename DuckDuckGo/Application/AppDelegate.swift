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
import CoreData
import BrowserServicesKit
import Persistence
import Configuration
import Networking
import Bookmarks
import DDGSync
import ServiceManagement
import SyncDataProviders
import UserNotifications

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

    private let fileStore: FileStore

    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    private let crashReporter = CrashReporter()
    let internalUserDecider: InternalUserDecider
    let featureFlagger: FeatureFlagger
    private var appIconChanger: AppIconChanger!

    private(set) var syncDataProviders: SyncDataProviders!
    private(set) var syncService: DDGSyncing?
    private var isSyncInProgressCancellable: AnyCancellable?
    private var screenLockedCancellable: AnyCancellable?
    private var emailCancellables = Set<AnyCancellable>()
    let bookmarksManager = LocalBookmarkManager.shared

    private var didFinishLaunching = false

#if SPARKLE
    var updateController: UpdateController!
#endif

    // swiftlint:disable:next function_body_length
    override init() {
        do {
            let encryptionKey = NSApplication.runType.requiresEnvironment ? try keyStore.readKey() : nil
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }

        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        internalUserDecider = DefaultInternalUserDecider(store: internalUserDeciderStore)

        if NSApplication.runType.requiresEnvironment {
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

            let preMigrationErrorHandling = EventMapping<BookmarkFormFactorFavoritesMigration.MigrationErrors> { _, error, _, _ in
                if let error = error {
                    Pixel.fire(.debug(event: .bookmarksCouldNotLoadDatabase, error: error))
                } else {
                    Pixel.fire(.debug(event: .bookmarksCouldNotLoadDatabase))
                }

                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not create Bookmarks database stack: \(error?.localizedDescription ?? "err")")
            }

            BookmarkDatabase.shared.preFormFactorSpecificFavoritesFolderOrder = BookmarkFormFactorFavoritesMigration
                .getFavoritesOrderFromPreV4Model(
                    dbContainerLocation: BookmarkDatabase.defaultDBLocation,
                    dbFileURL: BookmarkDatabase.defaultDBFileURL,
                    errorEvents: preMigrationErrorHandling
                )

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

#if DEBUG
        AppPrivacyFeatures.shared = NSApplication.runType.requiresEnvironment
        // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
        ? AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider), database: Database.shared)
        : AppPrivacyFeatures(contentBlocking: ContentBlockingMock(), httpsUpgradeStore: HTTPSUpgradeStoreMock())
#else
        AppPrivacyFeatures.shared = AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider), database: Database.shared)
#endif

        featureFlagger = DefaultFeatureFlagger(internalUserDecider: internalUserDecider,
                                               privacyConfig: AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        Configuration.setURLProvider(AppConfigurationURLProvider())

        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

#if SPARKLE
        updateController = UpdateController(internalUserDecider: internalUserDecider)
        stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
#endif

        appIconChanger = AppIconChanger(internalUserDecider: internalUserDecider)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSApp.runType.requiresEnvironment else { return }
        defer {
            didFinishLaunching = true
        }

        HistoryCoordinator.shared.loadHistory()
        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        bookmarksManager.loadBookmarks()
        if case .normal = NSApp.runType {
            FaviconManager.shared.loadFavicons()
        }
        ConfigurationManager.shared.start()
        FileDownloadManager.shared.delegate = self
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        // Clean up previous experiment
        if PixelExperiment.allocatedCohortDoesNotMatchCurrentCohorts {
            PixelExperiment.cleanup()
        }
        if LocalStatisticsStore().atb == nil {
            Pixel.firstLaunchDate = Date()
            // MARK: Enable pixel experiments here
            PixelExperiment.install()
        }
        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        let statisticsLoader = NSApp.runType.requiresEnvironment ? StatisticsLoader.shared : nil
        statisticsLoader?.load()

        startupSync()

        stateRestorationManager.applicationDidFinishLaunching()

        BWManager.shared.initCommunication()

        if WindowsManager.windows.first(where: { $0 is MainWindow }) == nil,
           case .normal = NSApp.runType {
            WindowsManager.openNewWindow(lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        crashReporter.checkForNewReports()

        urlEventHandler.applicationDidFinishLaunching()

        subscribeToEmailProtectionStatusNotifications()
        subscribeToDataImportCompleteNotification()

        UserDefaultsWrapper<Any>.clearRemovedKeys()

#if NETWORK_PROTECTION
        NetworkProtectionAppEvents().applicationDidFinishLaunching()
        UNUserNotificationCenter.current().delegate = self
#endif

#if DBP
        DataBrokerProtectionAppEvents().applicationDidFinishLaunching()
#endif
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard didFinishLaunching else { return }

        syncService?.initializeIfNeeded()
        syncService?.scheduler.notifyAppLifecycleEvent()

#if NETWORK_PROTECTION
        NetworkProtectionWaitlist().fetchNetworkProtectionInviteCodeIfAvailable { _ in
            // Do nothing when code fetching fails, as the app will try again later
        }

        NetworkProtectionAppEvents().applicationDidBecomeActive()
#endif

#if DBP
        DataBrokerProtectionAppEvents().applicationDidBecomeActive()
#endif
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
        if WindowControllersManager.shared.mainWindowControllers.isEmpty,
           case .normal = sender.runType {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
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
#if DEBUG
        let defaultEnvironment = ServerEnvironment.development
#else
        let defaultEnvironment = ServerEnvironment.production
#endif

#if DEBUG || REVIEW
        let environment = ServerEnvironment(
            UserDefaultsWrapper(
                key: .syncEnvironment,
                defaultValue: defaultEnvironment.description
            ).wrappedValue
        ) ?? defaultEnvironment
#else
        let environment = defaultEnvironment
#endif
        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db)
        let syncService = DDGSync(dataProvidersSource: syncDataProviders, errorEvents: SyncErrorHandler(), log: OSLog.sync, environment: environment)
        syncService.initializeIfNeeded()
        syncDataProviders.setUpDatabaseCleaners(syncService: syncService)

        // This is also called in applicationDidBecomeActive, but we're also calling it here, since
        // syncService can be nil when applicationDidBecomeActive is called during startup, if a modal
        // alert is shown before it's instantiated.  In any case it should be safe to call this here,
        // since the scheduler debounces calls to notifyAppLifecycleEvent().
        //
        syncService.scheduler.notifyAppLifecycleEvent()

        self.syncDataProviders = syncDataProviders
        self.syncService = syncService

        isSyncInProgressCancellable = syncService.isSyncInProgressPublisher
            .filter { $0 }
            .asVoid()
            .prefix(1)
            .sink {
                Pixel.fire(.syncDaily, limitTo: .dailyFirst)
            }

        subscribeSyncQueueToScreenLockedNotifications()
    }

    private func subscribeSyncQueueToScreenLockedNotifications() {
        let screenIsLockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsLocked"))
            .map { _ in true }
        let screenIsUnlockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsUnlocked"))
            .map { _ in false }

        screenLockedCancellable = Publishers.Merge(screenIsLockedPublisher, screenIsUnlockedPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                guard let syncService = self?.syncService, syncService.authState != .inactive else {
                    return
                }
                if isLocked {
                    os_log(.debug, log: .sync, "Screen is locked")
                    syncService.scheduler.cancelSyncAndSuspendSyncQueue()
                } else {
                    os_log(.debug, log: .sync, "Screen is unlocked")
                    syncService.scheduler.resumeSyncQueue()
                }
            }
    }

    private func subscribeToEmailProtectionStatusNotifications() {
        NotificationCenter.default.publisher(for: .emailDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.emailDidSignInNotification(notification)
            }
            .store(in: &emailCancellables)

        NotificationCenter.default.publisher(for: .emailDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.emailDidSignOutNotification(notification)
            }
            .store(in: &emailCancellables)
    }

    private func subscribeToDataImportCompleteNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(dataImportCompleteNotification(_:)), name: .dataImportComplete, object: nil)
    }

    private func emailDidSignInNotification(_ notification: Notification) {
        Pixel.fire(.emailEnabled)
        if Pixel.isNewUser {
            PixelExperiment.fireEmailProtectionEnabledPixel()
        }

        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    private func emailDidSignOutNotification(_ notification: Notification) {
        Pixel.fire(.emailDisabled)
        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    @objc private func dataImportCompleteNotification(_ notification: Notification) {
        if Pixel.isNewUser {
            PixelExperiment.fireImportDataInitialPixel()
        }
    }

}

#if NETWORK_PROTECTION || DBP

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.banner)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {

#if NETWORK_PROTECTION
            if response.notification.request.identifier == NetworkProtectionWaitlist.notificationIdentifier {
                if NetworkProtectionWaitlist().readyToAcceptTermsAndConditions {
                    DailyPixel.fire(pixel: .networkProtectionWaitlistNotificationTapped, frequency: .dailyAndCount, includeAppVersionParameter: true)
                    NetworkProtectionWaitlistViewControllerPresenter.show()
                }
            }
#endif

#if DBP
            if response.notification.request.identifier == DataBrokerProtectionWaitlist.notificationIdentifier {
                DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .localPush)
            }
#endif
        }

        completionHandler()
    }

}

#endif
