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

import Bookmarks
import BrowserServicesKit
import Cocoa
import Combine
import Common
import Configuration
import CoreData
import Crashes
import DDGSync
import History
import MetricKit
import Networking
import Persistence
import PixelKit
import ServiceManagement
import SyncDataProviders
import UserNotifications
import Lottie

import NetworkProtection
import Subscription
import NetworkProtectionIPC

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

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

    let fileStore: FileStore

#if APPSTORE
    private let crashCollection = CrashCollection(platform: .macOSAppStore, log: .default)
#else
    private let crashReporter = CrashReporter()
#endif

    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    let internalUserDecider: InternalUserDecider
    let featureFlagger: FeatureFlagger
    private var appIconChanger: AppIconChanger!
    private var autoClearHandler: AutoClearHandler!

    private(set) var syncDataProviders: SyncDataProviders!
    private(set) var syncService: DDGSyncing?
    private var isSyncInProgressCancellable: AnyCancellable?
    private var syncFeatureFlagsCancellable: AnyCancellable?
    private var screenLockedCancellable: AnyCancellable?
    private var emailCancellables = Set<AnyCancellable>()
    let bookmarksManager = LocalBookmarkManager.shared
    var privacyDashboardWindow: NSWindow?

    // Needs to be lazy as indirectly depends on AppDelegate
    private lazy var networkProtectionSubscriptionEventHandler: NetworkProtectionSubscriptionEventHandler = {

        let ipcClient = TunnelControllerIPCClient()
        let tunnelController = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)
        let vpnUninstaller = VPNUninstaller(ipcClient: ipcClient)

        return NetworkProtectionSubscriptionEventHandler(
            tunnelController: tunnelController,
            vpnUninstaller: vpnUninstaller)
    }()

#if DBP
    private let dataBrokerProtectionSubscriptionEventHandler = DataBrokerProtectionSubscriptionEventHandler()
#endif

    private var didFinishLaunching = false

#if SPARKLE
    var updateController: UpdateController!
#endif

    @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: Date.monthAgo)
    static var firstLaunchDate: Date

    static var isNewUser: Bool {
        return firstLaunchDate >= Date.weekAgo
    }

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
            Self.configurePixelKit()

            Database.shared.loadStore { _, error in
                guard let error = error else { return }

                switch error {
                case CoreDataDatabase.Error.containerLocationCouldNotBePrepared(let underlyingError):
                    PixelKit.fire(DebugEvent(GeneralPixel.dbContainerInitializationError(error: underlyingError)))
                default:
                    PixelKit.fire(DebugEvent(GeneralPixel.dbInitializationError(error: error)))
                }

                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }

            let preMigrationErrorHandling = EventMapping<BookmarkFormFactorFavoritesMigration.MigrationErrors> { _, error, _, _ in
                PixelKit.fire(DebugEvent(GeneralPixel.bookmarksCouldNotLoadDatabase(error: error)))
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
                    PixelKit.fire(DebugEvent(GeneralPixel.bookmarksCouldNotLoadDatabase(error: error)))
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

        featureFlagger = DefaultFeatureFlagger(
            internalUserDecider: internalUserDecider,
            privacyConfigManager: AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager
        )

    #if APPSTORE || !STRIPE
        SubscriptionPurchaseEnvironment.current = .appStore
    #else
        SubscriptionPurchaseEnvironment.current = .stripe
    #endif
    }

    static func configurePixelKit() {
#if DEBUG
            Self.setUpPixelKit(dryRun: true)
#else
            Self.setUpPixelKit(dryRun: false)
#endif
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        Configuration.setURLProvider(AppConfigurationURLProvider())

        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

#if SPARKLE
        if NSApp.runType != .uiTests {
            updateController = UpdateController(internalUserDecider: internalUserDecider)
            stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
        }
#endif

        appIconChanger = AppIconChanger(internalUserDecider: internalUserDecider)
    }

    // swiftlint:disable:next function_body_length
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSApp.runType.requiresEnvironment else { return }
        defer {
            didFinishLaunching = true
        }

        HistoryCoordinator.shared.loadHistory {
            HistoryCoordinator.shared.migrateModelV5toV6IfNeeded()
        }

        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        bookmarksManager.loadBookmarks()

        // Force use of .mainThread to prevent high WindowServer Usage
        // Pending Fix with newer Lottie versions
        // https://app.asana.com/0/1177771139624306/1207024603216659/f
        LottieConfiguration.shared.renderingEngine = .mainThread

        if case .normal = NSApp.runType {
            FaviconManager.shared.loadFavicons()
        }
        ConfigurationManager.shared.start()
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        // Clean up previous experiment
//        if PixelExperiment.allocatedCohortDoesNotMatchCurrentCohorts { // Re-implement https://app.asana.com/0/0/1207002879349166/f
//            PixelExperiment.cleanup()
//        }

        if LocalStatisticsStore().atb == nil {
            AppDelegate.firstLaunchDate = Date()
            // MARK: Enable pixel experiments here
        }
        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        let statisticsLoader = NSApp.runType.requiresEnvironment ? StatisticsLoader.shared : nil
        statisticsLoader?.load()

        startupSync()

        let defaultEnvironment = SubscriptionPurchaseEnvironment.ServiceEnvironment.default

        let currentEnvironment = UserDefaultsWrapper(key: .subscriptionEnvironment,
                                                     defaultValue: defaultEnvironment).wrappedValue
        SubscriptionPurchaseEnvironment.currentServiceEnvironment = currentEnvironment

        Task {
            let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
            if let token = accountManager.accessToken {
                _ = await SubscriptionService.getSubscription(accessToken: token, cachePolicy: .reloadIgnoringLocalCacheData)
                _ = await accountManager.fetchEntitlements(cachePolicy: .reloadIgnoringLocalCacheData)
            }
        }

        if [.normal, .uiTests].contains(NSApp.runType) {
            stateRestorationManager.applicationDidFinishLaunching()
        }

        BWManager.shared.initCommunication()

        if WindowsManager.windows.first(where: { $0 is MainWindow }) == nil,
           case .normal = NSApp.runType {
            WindowsManager.openNewWindow(lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

#if APPSTORE
        crashCollection.start { pixelParameters, payloads, completion in
            pixelParameters.forEach { _ in PixelKit.fire(GeneralPixel.crash) }
            guard let lastPayload = payloads.last else {
                return
            }
            DispatchQueue.main.async {
                CrashReportPromptPresenter().showPrompt(for: lastPayload, userDidAllowToReport: completion)
            }
        }
#else
        crashReporter.checkForNewReports()
#endif

        urlEventHandler.applicationDidFinishLaunching()

        subscribeToEmailProtectionStatusNotifications()
        subscribeToDataImportCompleteNotification()

        fireFailedCompilationsPixelIfNeeded()

        UserDefaultsWrapper<Any>.clearRemovedKeys()

        networkProtectionSubscriptionEventHandler.registerForSubscriptionAccountManagerEvents()

        NetworkProtectionAppEvents().applicationDidFinishLaunching()
        UNUserNotificationCenter.current().delegate = self

#if DBP
        dataBrokerProtectionSubscriptionEventHandler.registerForSubscriptionAccountManagerEvents()
#endif

#if DBP
        DataBrokerProtectionAppEvents().applicationDidFinishLaunching()
#endif

        setUpAutoClearHandler()
    }

    private func fireFailedCompilationsPixelIfNeeded() {
        let store = FailedCompilationsStore()
        if store.hasAnyFailures {
            PixelKit.fire(DebugEvent(GeneralPixel.compilationFailed),
                          frequency: .daily,
                          withAdditionalParameters: store.summary, 
                          includeAppVersionParameter: true) { didFire, _ in
                if !didFire {
                    store.cleanup()
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard didFinishLaunching else { return }

        syncService?.initializeIfNeeded()
        syncService?.scheduler.notifyAppLifecycleEvent()

        NetworkProtectionAppEvents().applicationDidBecomeActive()

#if DBP
        DataBrokerProtectionAppEvents().applicationDidBecomeActive()
#endif

        AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.toggleProtectionsCounter.sendEventsIfNeeded()

        updateSubscriptionStatus()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !FileDownloadManager.shared.downloads.isEmpty {
            // if there‘re downloads without location chosen yet (save dialog should display) - ignore them
            if FileDownloadManager.shared.downloads.contains(where: { $0.state.isDownloading }) {
                let alert = NSAlert.activeDownloadsTerminationAlert(for: FileDownloadManager.shared.downloads)
                if alert.runModal() == .cancel {
                    return .terminateCancel
                }
            }
            FileDownloadManager.shared.cancelAll(waitUntilDone: true)
            DownloadListCoordinator.shared.sync()
        }
        stateRestorationManager?.applicationWillTerminate()

        // Handling of "Burn on quit"
        if let terminationReply = autoClearHandler.handleAppTermination() {
            return terminationReply
        }

        return .terminateNow
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

    private static func setUpPixelKit(dryRun: Bool) {
#if APPSTORE
        let source = "browser-appstore"
#else
        let source = "browser-dmg"
#endif

        PixelKit.setUp(dryRun: dryRun,
                       appVersion: AppVersion.shared.versionNumber,
                       source: source,
                       defaultHeaders: [:],
                       defaults: .netP) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping PixelKit.CompletionBlock) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers)
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error == nil, error)
            }
        }
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
        let syncErrorHandler = SyncErrorHandler()
        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db, syncErrorHandler: syncErrorHandler)
        let syncService = DDGSync(
            dataProvidersSource: syncDataProviders,
            errorEvents: SyncErrorHandler(),
            privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager,
            log: OSLog.sync,
            environment: environment
        )
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
            .sink { [weak syncService] in
                PixelKit.fire(GeneralPixel.syncDaily, frequency: .legacyDaily)
                syncService?.syncDailyStats.sendStatsIfNeeded(handler: { params in
                    PixelKit.fire(GeneralPixel.syncSuccessRateDaily, withAdditionalParameters: params)
                })
            }

        subscribeSyncQueueToScreenLockedNotifications()
        subscribeToSyncFeatureFlags(syncService)
    }

    @UserDefaultsWrapper(key: .syncDidShowSyncPausedByFeatureFlagAlert, defaultValue: false)
    private var syncDidShowSyncPausedByFeatureFlagAlert: Bool

    private func subscribeToSyncFeatureFlags(_ syncService: DDGSync) {
        syncFeatureFlagsCancellable = syncService.featureFlagsPublisher
            .dropFirst()
            .map { $0.contains(.dataSyncing) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak syncService] isDataSyncingAvailable in
                if isDataSyncingAvailable {
                    self?.syncDidShowSyncPausedByFeatureFlagAlert = false
                } else if syncService?.authState == .active, self?.syncDidShowSyncPausedByFeatureFlagAlert == false {
                    let isSyncUIVisible = syncService?.featureFlags.contains(.userInterface) == true
                    let alert = NSAlert.dataSyncingDisabledByFeatureFlag(showLearnMore: isSyncUIVisible)
                    let response = alert.runModal()
                    self?.syncDidShowSyncPausedByFeatureFlagAlert = true

                    switch response {
                    case .alertSecondButtonReturn:
                        alert.window.sheetParent?.endSheet(alert.window)
                        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .sync)
                    default:
                        break
                    }
                }
            }
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
        PixelKit.fire(NonStandardEvent(NonStandardPixel.emailEnabled))
        if AppDelegate.isNewUser {
            PixelKit.fire(GeneralPixel.emailEnabledInitial, frequency: .legacyInitial)
        }

        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    private func emailDidSignOutNotification(_ notification: Notification) {
        PixelKit.fire(NonStandardEvent(NonStandardPixel.emailDisabled))
        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    @objc private func dataImportCompleteNotification(_ notification: Notification) {
        if AppDelegate.isNewUser {
            PixelKit.fire(GeneralPixel.importDataInitial, frequency: .legacyInitial)
        }
    }

    private func setUpAutoClearHandler() {
        autoClearHandler = AutoClearHandler(preferences: .shared,
                                            fireViewModel: FireCoordinator.fireViewModel,
                                            stateRestorationManager: stateRestorationManager)
        autoClearHandler.handleAppLaunch()
        autoClearHandler.onAutoClearCompleted = {
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
    }

}

func updateSubscriptionStatus() {
    Task {
        let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))

        guard let token = accountManager.accessToken else { return }

        if case .success(let subscription) = await SubscriptionService.getSubscription(accessToken: token, cachePolicy: .reloadIgnoringLocalCacheData) {
            if subscription.isActive {
                PixelKit.fire(PrivacyProPixel.privacyProSubscriptionActive, frequency: .daily)
            }
        }

        _ = await accountManager.fetchEntitlements(cachePolicy: .reloadIgnoringLocalCacheData)
    }
}

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

#if DBP
            if response.notification.request.identifier == DataBrokerProtectionWaitlist.notificationIdentifier {
                DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .localPush)
            }
#endif
        }

        completionHandler()
    }

}
