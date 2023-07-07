//
//  AppDependencies.swift
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

import AppKit
import BrowserServicesKit
import Common
import DDGSync
import Foundation
import SyncDataProviders

struct WindowManagerDependencies: WindowManager.Dependencies {

    let pinnedTabsManager: PinnedTabsManager

}

struct RecentlyClosedCoordinatorDependencies: RecentlyClosedCoordinator.Dependencies & AutoTabDependencies {

    let tabDependencies: TabDependencies

    let pinnedTabsManager: PinnedTabsManager
    let windowManager: WindowManagerProtocol

    init(tabDependencies: TabDependencies, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager) {
        self.tabDependencies = tabDependencies
        self.pinnedTabsManager = pinnedTabsManager
        self.windowManager = windowManager
    }

}

struct FireDependencies: Fire.Dependencies & AutoTabDependencies {

    let tabDependencies: TabDependencies

    let downloadListCoordinator: DownloadListCoordinator
    let recentlyClosedCoordinator: RecentlyClosedCoordinating

    let pinnedTabsManager: PinnedTabsManager
    let windowManager: WindowManagerProtocol

    let syncService: DDGSyncing?

    var stateRestorationManager: AppStateRestorationManager?

    init(tabDependencies: TabDependencies, downloadListCoordinator: DownloadListCoordinator, recentlyClosedCoordinator: RecentlyClosedCoordinating, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, syncService: DDGSyncing?, stateRestorationManager: AppStateRestorationManager?) {
        self.tabDependencies = tabDependencies

        self.downloadListCoordinator = downloadListCoordinator
        self.recentlyClosedCoordinator = recentlyClosedCoordinator

        self.pinnedTabsManager = pinnedTabsManager
        self.windowManager = windowManager
        self.syncService = syncService
        self.stateRestorationManager = stateRestorationManager
    }

}

struct FireCoordinatorDependencies: FireCoordinator.Dependencies {
    let faviconManagement: FaviconManagement

    let windowManager: WindowManagerProtocol

    let fireViewModel: FireViewModel

    let historyCoordinating: HistoryCoordinating

    @MainActor
    init(tabDependencies: TabDependencies, downloadListCoordinator: DownloadListCoordinator, recentlyClosedCoordinator: RecentlyClosedCoordinating, pinnedTabsManager: PinnedTabsManager, faviconManagement: FaviconManagement, bookmarkManager: BookmarkManager, windowManager: WindowManager, syncService: DDGSyncing?, stateRestorationManager: AppStateRestorationManager?) {
        let fireDependencies = FireDependencies(tabDependencies: tabDependencies,
                                                downloadListCoordinator: downloadListCoordinator,
                                                recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                pinnedTabsManager: pinnedTabsManager,
                                                windowManager: windowManager,
                                                syncService: syncService,
                                                stateRestorationManager: stateRestorationManager)
        self.fireViewModel = FireViewModel(fire: Fire(dependencyProvider: fireDependencies))
        self.faviconManagement = faviconManagement
        self.historyCoordinating = tabDependencies.historyCoordinating
        self.windowManager = windowManager
    }

}

struct WindowManagerNestedDependencies: AbstractWindowManagerNestedDependencies.Dependencies & AutoTabDependencies {

    let tabDependencies: TabDependencies
    let configurationManager: ConfigurationManager
    let faviconManagement: FaviconManagement

    let emailManager = BrowserServicesKit.EmailManager()
    let urlMatcher: BrowserServicesKit.AutofillUrlMatcher = AutofillDomainNameUrlMatcher()
    let downloadListCoordinator: DownloadListCoordinator

    let internalUserDecider: BrowserServicesKit.InternalUserDecider
    let syncService: DDGSyncing

    let fireViewModel: FireViewModel
    var fire: Fire { fireViewModel.fire }

    let fireCoordinator: FireCoordinator

    let pinnedTabsManager: PinnedTabsManager?

    let windowManager: WindowManagerProtocol

    var duckPlayerPreferences: DuckPlayerPreferences

    var scriptSourceProvider: ScriptSourceProviding

    @MainActor
    init(tabDependencies: TabDependencies,
         configurationManager: ConfigurationManager,
         faviconManagement: FaviconManagement,
         internalUserDecider: BrowserServicesKit.InternalUserDecider,
         syncService: DDGSyncing,
         recentlyClosedCoordinator: RecentlyClosedCoordinating,
         downloadListCoordinator: DownloadListCoordinator,
         fireViewModel: FireViewModel,
         fireCoordinator: FireCoordinator,
         pinnedTabsManager: PinnedTabsManager,
         windowManager: WindowManager,
         duckPlayerPreferences: DuckPlayerPreferences,
         scriptSourceProvider: ScriptSourceProviding) {

        self.tabDependencies = tabDependencies
        self.configurationManager = configurationManager
        self.faviconManagement = faviconManagement

        self.internalUserDecider = internalUserDecider
        self.downloadListCoordinator = downloadListCoordinator
        self.syncService = syncService

        self.fireViewModel = fireViewModel
        self.fireCoordinator = fireCoordinator

        self.pinnedTabsManager = pinnedTabsManager

        self.windowManager = windowManager

        self.duckPlayerPreferences = duckPlayerPreferences
        self.scriptSourceProvider = scriptSourceProvider
    }

}

struct StateRestorationManagerDependencies: AppStateRestorationManager.Dependencies & AutoTabDependencies {

    let tabDependencies: TabDependencies

    let statePersistenceService: StatePersistenceService

    let pinnedTabsManager: PinnedTabsManager?
    let passwordManagerCoordinator: PasswordManagerCoordinating

    let windowManager: WindowManager

    @MainActor
    init(tabDependencies: TabDependencies, statePersistenceService: StatePersistenceService, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.tabDependencies = tabDependencies
        self.statePersistenceService = statePersistenceService
        self.pinnedTabsManager = pinnedTabsManager
        self.windowManager = windowManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
    }

}

struct PasswordManagerCoordinatorDependencies: PasswordManagerCoordinator.Dependencies {
    var bitwardenManagement: BWManagement
    var windowManager: WindowManagerProtocol
}

struct DownloadListCoordinatorDependencies: DownloadListCoordinator.Dependencies {
    var windowManager: WindowManagerProtocol
    var downloadManager: FileDownloadManagerProtocol
}

struct TabDependencies: Tab.Dependencies {
    var bookmarkManager: BookmarkManager

    var faviconManagement: FaviconManagement

    var pinnedTabsManager: PinnedTabsManager?

    var passwordManagerCoordinator: PasswordManagerCoordinating

    var privacyFeatures: PrivacyFeaturesProtocol

    var contentBlocking: AnyContentBlocking { privacyFeatures.contentBlocking }

    var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?

    var privacyConfigurationManager: BrowserServicesKit.PrivacyConfigurationManaging {
        contentBlocking.privacyConfigurationManager
    }

    var contentBlockingManager: ContentBlockerRulesManagerProtocol {
        contentBlocking.contentBlockingManager
    }

    var now: () -> Date

    var attributionFeatureConfig: BrowserServicesKit.AdClickAttributing {
        contentBlocking.adClickAttribution
    }

    var attributionRulesProvider: BrowserServicesKit.AdClickAttributionRulesProviding {
        contentBlocking.adClickAttributionRulesProvider
    }

    var tld: Common.TLD {
        contentBlocking.tld
    }

    let attributionEvents: Common.EventMapping<BrowserServicesKit.AdClickAttributionEvents>?

    let attributionDebugEvents: Common.EventMapping<BrowserServicesKit.AdClickAttributionDebugEvents>?

    let tabExtensionsBuilder: TabExtensionsBuilderProtocol = TabExtensionsBuilder.default

    let attributionLog: () -> Common.OSLog

    let duckPlayer: DuckPlayer

    let historyCoordinating: HistoryCoordinating

    let workspace: Workspace = NSWorkspace.shared

    let downloadManager: FileDownloadManagerProtocol
}

protocol AutoTabDependencies: Tab.Dependencies {
    var tabDependencies: TabDependencies { get }
}
extension AutoTabDependencies {

    var bookmarkManager: BookmarkManager { tabDependencies.bookmarkManager }

    var faviconManagement: FaviconManagement { tabDependencies.faviconManagement }

    var pinnedTabsManager: PinnedTabsManager? { tabDependencies.pinnedTabsManager }

    var passwordManagerCoordinator: PasswordManagerCoordinating { tabDependencies.passwordManagerCoordinator }

    var privacyFeatures: PrivacyFeaturesProtocol { tabDependencies.privacyFeatures }

    var contentBlocking: AnyContentBlocking { tabDependencies.contentBlocking }

    var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? { tabDependencies.cbaTimeReporter }

    var privacyConfigurationManager: BrowserServicesKit.PrivacyConfigurationManaging { tabDependencies.privacyConfigurationManager }

    var contentBlockingManager: ContentBlockerRulesManagerProtocol { tabDependencies.contentBlockingManager }

    var now: () -> Date { tabDependencies.now }

    var attributionFeatureConfig: BrowserServicesKit.AdClickAttributing { tabDependencies.attributionFeatureConfig }

    var attributionRulesProvider: BrowserServicesKit.AdClickAttributionRulesProviding { tabDependencies.attributionRulesProvider }

    var tld: Common.TLD { tabDependencies.tld }

    var attributionEvents: Common.EventMapping<BrowserServicesKit.AdClickAttributionEvents>? { tabDependencies.attributionEvents }

    var attributionDebugEvents: Common.EventMapping<BrowserServicesKit.AdClickAttributionDebugEvents>? { tabDependencies.attributionDebugEvents }

    var tabExtensionsBuilder: TabExtensionsBuilderProtocol { tabDependencies.tabExtensionsBuilder }

    var attributionLog: () -> Common.OSLog { tabDependencies.attributionLog }

    var duckPlayer: DuckPlayer { tabDependencies.duckPlayer }

    var historyCoordinating: HistoryCoordinating { tabDependencies.historyCoordinating }

    var workspace: Workspace { tabDependencies.workspace }

    var downloadManager: FileDownloadManagerProtocol { tabDependencies.downloadManager }

}

struct ConfigurationManagerDependencies: ConfigurationManager.Dependencies {
    let privacyFeatures: PrivacyFeaturesProtocol
    var contentBlocking: AnyContentBlocking { privacyFeatures.contentBlocking }
}

struct LocalBookmarkStoreDependencies: LocalBookmarkStore.Dependencies {
    let duckPlayer: DuckPlayer

    let faviconManagement: FaviconManagement
}
struct LocalBookmarkManagerDependencies: LocalBookmarkManager.Dependencies {
    let bookmarkStore: BookmarkStore

    let faviconManagement: FaviconManagement

    let duckPlayer: DuckPlayer

    let syncService: () -> DDGSyncing?
}

struct AppDependencies: AppDelegate.Dependencies & MainMenu.Dependencies & HistoryMenu.Dependencies & AutoTabDependencies {

    let privacyFeatures: PrivacyFeaturesProtocol
    let tabDependencies: TabDependencies

    let windowManager: WindowManagerProtocol
    let syncService: DDGSyncing
    let urlEventHandler: URLEventHandler
    let internalUserDecider: InternalUserDecider
    let downloadListCoordinator: DownloadListCoordinator
    let stateRestorationManager: AppStateRestorationManager?
    let recentlyClosedCoordinator: RecentlyClosedCoordinator
    let fireCoordinator: FireCoordinator

    let pinnedTabsManager: PinnedTabsManager
    let passwordManagerCoordinator: PasswordManagerCoordinating

    let configurationManager: ConfigurationManager

    let historyCoordinator: HistoryCoordinator
    let downloadManager: FileDownloadManager

    @MainActor
    init() { // swiftlint:disable:this function_body_length
#if CI
        let keyStore = (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
#else
        let keyStore = EncryptionKeyStore()
#endif
        let fileStore: FileStore
        do {
            let encryptionKey = try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        self.internalUserDecider = {
            let internalUserDecider = DefaultInternalUserDecider(store: internalUserDeciderStore)
#if DEBUG
            let url = URL(string: "https://use-login.duckduckgo.com")!
            internalUserDecider.markUserAsInternalIfNeeded(forUrl: url, response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
#endif
            return internalUserDecider
        }()

        let pinnedTabsManager = PinnedTabsManager()
        let windowManagerDependencies = WindowManagerDependencies(pinnedTabsManager: pinnedTabsManager)

        var recentlyClosedCoordinator: RecentlyClosedCoordinator!
        var fireCoordinator: FireCoordinator!
        var downloadListCoordinator: DownloadListCoordinator!
        var passwordManagerCoordinator: PasswordManagerCoordinator!
        var tabDependencies: TabDependencies!
        var stateRestorationManager: AppStateRestorationManager!

        var duckPlayer: DuckPlayer!
        let contentBlocking = AppContentBlocking(internalUserDecider: internalUserDecider, duckPlayer: { duckPlayer! })
        let privacyFeatures = AppPrivacyFeatures(contentBlocking: contentBlocking, database: Database.shared)
        self.privacyFeatures = privacyFeatures

        let duckPlayerPreferences = DuckPlayerPreferences()
        duckPlayer = DuckPlayer(preferences: duckPlayerPreferences, privacyConfigurationManager: contentBlocking.privacyConfigurationManager)

        let configurationManagerDependencies = ConfigurationManagerDependencies(privacyFeatures: privacyFeatures)
        configurationManager = ConfigurationManager(dependencyProvider: configurationManagerDependencies)

        let scriptSourceProvider = ScriptSourceProvider(configStorage: ConfigurationStore.shared,
                                                        privacyConfigurationManager: contentBlocking.privacyConfigurationManager,
                                                        privacySettings: PrivacySecurityPreferences.shared,
                                                        contentBlockingManager: contentBlocking.contentBlockingManager,
                                                        trackerDataManager: contentBlocking.trackerDataManager,
                                                        tld: contentBlocking.tld)

        let faviconManagement = FaviconManager(cacheType: .standard)

        let localBookmarkStoreDependencies = LocalBookmarkStoreDependencies(duckPlayer: duckPlayer, faviconManagement: faviconManagement)
        let bookmarkStore = LocalBookmarkStore(bookmarkDatabase: BookmarkDatabase.shared, dependencyProvider: localBookmarkStoreDependencies)

        var syncService: DDGSync!
        let localBookmarkManagerDependencies = LocalBookmarkManagerDependencies(bookmarkStore: bookmarkStore,
                                                                                faviconManagement: faviconManagement,
                                                                                duckPlayer: duckPlayer,
                                                                                syncService: { syncService })
        let bookmarkManager = LocalBookmarkManager(dependencyProvider: localBookmarkManagerDependencies)

        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db, bookmarkManager: bookmarkManager)
        syncService = DDGSync(dataProvidersSource: syncDataProviders, errorEvents: SyncErrorHandler(), log: OSLog.sync)
        self.syncService = syncService

        let historyStore = HistoryStore()
        historyCoordinator = HistoryCoordinator(historyStoring: historyStore)

        downloadManager = FileDownloadManager()

        let windowManager = WindowManager(
            dependencyProvider: windowManagerDependencies
        ) { [internalUserDecider, configurationManager, downloadManager, historyCoordinator] windowManager in

            let downloadListCoordinatorDependencies = DownloadListCoordinatorDependencies(windowManager: windowManager,
                                                                                          downloadManager: downloadManager)
            downloadListCoordinator = DownloadListCoordinator(dependencyProvider: downloadListCoordinatorDependencies)

            let passwordManagerCoordinatorDependencies = PasswordManagerCoordinatorDependencies(bitwardenManagement: BWManager.shared,
                                                                                                windowManager: windowManager)
            passwordManagerCoordinator = PasswordManagerCoordinator(dependencyProvider: passwordManagerCoordinatorDependencies)

            tabDependencies = TabDependencies(bookmarkManager: bookmarkManager,
                                              faviconManagement: faviconManagement,
                                              passwordManagerCoordinator: passwordManagerCoordinator,
                                              privacyFeatures: privacyFeatures,
                                              cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter.shared,
                                              now: Date.init,
                                              attributionEvents: contentBlocking.attributionEvents,
                                              attributionDebugEvents: contentBlocking.attributionDebugEvents,
                                              attributionLog: { OSLog.attribution },
                                              duckPlayer: duckPlayer,
                                              historyCoordinating: historyCoordinator,
                                              downloadManager: downloadManager)

            let recentlyClosedCoordinatorDependencies = RecentlyClosedCoordinatorDependencies(tabDependencies: tabDependencies,
                                                                                              pinnedTabsManager: pinnedTabsManager,
                                                                                              windowManager: windowManager)
            recentlyClosedCoordinator = RecentlyClosedCoordinator(dependencyProvider: recentlyClosedCoordinatorDependencies)

            let statePersistenceService = StatePersistenceService(fileStore: fileStore, fileName: AppStateRestorationManager.fileName)
            let stateRestorationManagerDependencies = StateRestorationManagerDependencies(tabDependencies: tabDependencies,
                                                                                          statePersistenceService: statePersistenceService,
                                                                                          pinnedTabsManager: pinnedTabsManager,
                                                                                          windowManager: windowManager,
                                                                                          passwordManagerCoordinator: passwordManagerCoordinator)
            stateRestorationManager = AppStateRestorationManager(dependencyProvider: stateRestorationManagerDependencies,
                                                                 shouldRestorePreviousSession: StartupPreferences().restorePreviousSession)

            let fireCoordinatorDependencies = FireCoordinatorDependencies(tabDependencies: tabDependencies,
                                                                          downloadListCoordinator: downloadListCoordinator,
                                                                          recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                                          pinnedTabsManager: pinnedTabsManager,
                                                                          faviconManagement: faviconManagement,
                                                                          bookmarkManager: bookmarkManager,
                                                                          windowManager: windowManager,
                                                                          syncService: syncService,
                                                                          stateRestorationManager: stateRestorationManager)
            fireCoordinator = FireCoordinator(dependencyProvider: fireCoordinatorDependencies)

            return WindowManagerNestedDependencies(tabDependencies: tabDependencies,
                                                   configurationManager: configurationManager,
                                                   faviconManagement: faviconManagement,
                                                   internalUserDecider: internalUserDecider,
                                                   syncService: syncService,
                                                   recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                   downloadListCoordinator: downloadListCoordinator,
                                                   fireViewModel: fireCoordinatorDependencies.fireViewModel,
                                                   fireCoordinator: fireCoordinator,
                                                   pinnedTabsManager: pinnedTabsManager,
                                                   windowManager: windowManager,
                                                   duckPlayerPreferences: duckPlayerPreferences,
                                                   scriptSourceProvider: scriptSourceProvider)
        }
        self.pinnedTabsManager = pinnedTabsManager
        self.windowManager = windowManager
        self.tabDependencies = tabDependencies
        self.urlEventHandler = URLEventHandler(windowManager: windowManager)

        self.stateRestorationManager = stateRestorationManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.recentlyClosedCoordinator = recentlyClosedCoordinator
        self.fireCoordinator = fireCoordinator
        self.downloadListCoordinator = downloadListCoordinator
    }

}
