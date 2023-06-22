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

struct RecentlyClosedCoordinatorDependencies: RecentlyClosedCoordinator.Dependencies {

    let pinnedTabsManagerValue: PinnedTabsManager
    @_implements(Tab_InjectedVars, pinnedTabsManager)
    var tabPinnedTabsManager: PinnedTabsManager? { pinnedTabsManagerValue }
    var pinnedTabsManager: PinnedTabsManager { pinnedTabsManagerValue }
    let passwordManagerCoordinator: PasswordManagerCoordinating

    let windowManager: WindowManagerProtocol

    init(pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.pinnedTabsManagerValue = pinnedTabsManager
        self.windowManager = windowManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
    }

}

struct FireDependencies: Fire.Dependencies {

    let downloadListCoordinator: DownloadListCoordinator
    let recentlyClosedCoordinator: RecentlyClosedCoordinating

    let pinnedTabsManagerValue: PinnedTabsManager
    @_implements(Tab_InjectedVars, pinnedTabsManager)
    var tabPinnedTabsManager: PinnedTabsManager? { pinnedTabsManagerValue }
    var pinnedTabsManager: PinnedTabsManager { pinnedTabsManagerValue }
    let passwordManagerCoordinator: PasswordManagerCoordinating

    let windowManager: WindowManagerProtocol

    init(downloadListCoordinator: DownloadListCoordinator, recentlyClosedCoordinator: RecentlyClosedCoordinating, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.downloadListCoordinator = downloadListCoordinator
        self.recentlyClosedCoordinator = recentlyClosedCoordinator

        self.pinnedTabsManagerValue = pinnedTabsManager
        self.windowManager = windowManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
    }

}

struct FireCoordinatorDependencies: FireCoordinator.Dependencies {
    let pinnedTabsManagerValue: PinnedTabsManager
    let downloadListCoordinator: DownloadListCoordinator

    var pinnedTabsManager: PinnedTabsManager? { pinnedTabsManagerValue }

    let windowManager: WindowManagerProtocol

    let fireViewModel: FireViewModel

    @MainActor
    init(downloadListCoordinator: DownloadListCoordinator, recentlyClosedCoordinator: RecentlyClosedCoordinating, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, passwordManagerCoordinator: PasswordManagerCoordinating) {
        let fireDependencies = FireDependencies(downloadListCoordinator: downloadListCoordinator,
                                                recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                pinnedTabsManager: pinnedTabsManager,
                                                windowManager: windowManager,
                                                passwordManagerCoordinator: passwordManagerCoordinator)
        self.fireViewModel = FireViewModel(fire: Fire(dependencyProvider: fireDependencies))

        self.downloadListCoordinator = downloadListCoordinator
        self.pinnedTabsManagerValue = pinnedTabsManager
        self.windowManager = windowManager
    }

}

struct WindowManagerNestedDependencies: AbstractWindowManagerNestedDependencies.Dependencies {

    let emailManager = BrowserServicesKit.EmailManager()
    let passwordManagerCoordinator: PasswordManagerCoordinating
    let urlMatcher: BrowserServicesKit.AutofillUrlMatcher = AutofillDomainNameUrlMatcher()
    let downloadListCoordinator: DownloadListCoordinator

    let internalUserDecider: BrowserServicesKit.InternalUserDecider
    let syncService: DDGSyncing

    let fireViewModel: FireViewModel
    let fireCoordinator: FireCoordinator

    let pinnedTabsManager: PinnedTabsManager?

    let windowManager: WindowManagerProtocol

    @MainActor
    init(internalUserDecider: BrowserServicesKit.InternalUserDecider,
         syncService: DDGSyncing,
         recentlyClosedCoordinator: RecentlyClosedCoordinating,
         downloadListCoordinator: DownloadListCoordinator,
         fireViewModel: FireViewModel,
         fireCoordinator: FireCoordinator,
         pinnedTabsManager: PinnedTabsManager,
         passwordManagerCoordinator: PasswordManagerCoordinating,
         windowManager: WindowManager) {

        self.internalUserDecider = internalUserDecider
        self.downloadListCoordinator = downloadListCoordinator
        self.syncService = syncService

        self.fireViewModel = fireViewModel
        self.fireCoordinator = fireCoordinator

        self.pinnedTabsManager = pinnedTabsManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.windowManager = windowManager
    }

}

struct StateRestorationManagerDependencies: AppStateRestorationManager.Dependencies {
    let statePersistenceService: StatePersistenceService

    let pinnedTabsManager: PinnedTabsManager?
    let passwordManagerCoordinator: PasswordManagerCoordinating

    let windowManager: WindowManager

    @MainActor
    init(statePersistenceService: StatePersistenceService, pinnedTabsManager: PinnedTabsManager, windowManager: WindowManager, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.statePersistenceService = statePersistenceService
        self.pinnedTabsManager = pinnedTabsManager
        self.windowManager = windowManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
    }

}

struct AppDependencies: AppDelegate.Dependencies & MainMenu.Dependencies & HistoryMenu.Dependencies & Tab.DependencyProvider {

    let windowManager: WindowManagerProtocol
    let syncService: DDGSyncing
    let urlEventHandler: URLEventHandler
    let internalUserDecider: InternalUserDecider
    let downloadListCoordinator: DownloadListCoordinator
    let stateRestorationManager: AppStateRestorationManager
    let recentlyClosedCoordinator: RecentlyClosedCoordinator
    let fireCoordinator: FireCoordinator

    let pinnedTabsManagerValue: PinnedTabsManager
    @_implements(Tab_InjectedVars, pinnedTabsManager)
    var tabPinnedTabsManager: PinnedTabsManager? { pinnedTabsManagerValue }
    @_implements(TabCollectionViewModel_InjectedVars, pinnedTabsManager)
    var tabcvmPinnedTabsManager: PinnedTabsManager? { pinnedTabsManagerValue }
    var pinnedTabsManager: PinnedTabsManager { pinnedTabsManagerValue }
    let passwordManagerCoordinator: PasswordManagerCoordinating

    @MainActor
    init(isRunningUnitTests: Bool) { // swiftlint:disable:this function_body_length
#if CI
        let keyStore = (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
#else
        let keyStore = EncryptionKeyStore()
#endif
        let fileStore: FileStore
        do {
            let encryptionKey = isRunningUnitTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        self.internalUserDecider = DefaultInternalUserDecider(store: internalUserDeciderStore)

        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db)
        self.syncService = DDGSync(dataProvidersSource: syncDataProviders, errorEvents: SyncErrorHandler(), log: OSLog.sync)

        let pinnedTabsManager = PinnedTabsManager()
        let windowManagerDependencies = WindowManagerDependencies(pinnedTabsManager: pinnedTabsManager)

        var recentlyClosedCoordinator: RecentlyClosedCoordinator!
        var fireCoordinator: FireCoordinator!
        var downloadListCoordinator: DownloadListCoordinator!
        var passwordManagerCoordinator: PasswordManagerCoordinator!

        let windowManager = WindowManager(dependencyProvider: windowManagerDependencies) { [internalUserDecider, syncService] windowManager in

            downloadListCoordinator = DownloadListCoordinator(windowManager: windowManager)
            passwordManagerCoordinator = PasswordManagerCoordinator(bitwardenManagement: BWManager.shared, windowManager: windowManager)

            let recentlyClosedCoordinatorDependencies = RecentlyClosedCoordinatorDependencies(pinnedTabsManager: pinnedTabsManager, windowManager: windowManager, passwordManagerCoordinator: passwordManagerCoordinator)
            recentlyClosedCoordinator = RecentlyClosedCoordinator(dependencyProvider: recentlyClosedCoordinatorDependencies)

            let fireCoordinatorDependencies = FireCoordinatorDependencies(downloadListCoordinator: downloadListCoordinator,
                                                                          recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                                          pinnedTabsManager: pinnedTabsManager,
                                                                          windowManager: windowManager,
                                                                          passwordManagerCoordinator: passwordManagerCoordinator)
            fireCoordinator = FireCoordinator(dependencyProvider: fireCoordinatorDependencies)

            return WindowManagerNestedDependencies(internalUserDecider: internalUserDecider,
                                                   syncService: syncService,
                                                   recentlyClosedCoordinator: recentlyClosedCoordinator,
                                                   downloadListCoordinator: downloadListCoordinator,
                                                   fireViewModel: fireCoordinatorDependencies.fireViewModel,
                                                   fireCoordinator: fireCoordinator,
                                                   pinnedTabsManager: pinnedTabsManager,
                                                   passwordManagerCoordinator: passwordManagerCoordinator,
                                                   windowManager: windowManager)
        }
        self.windowManager = windowManager
        self.urlEventHandler = URLEventHandler(windowManager: windowManager)

        let statePersistenceService = StatePersistenceService(fileStore: fileStore, fileName: AppStateRestorationManager.fileName)
        let stateRestorationManagerDependencies = StateRestorationManagerDependencies(statePersistenceService: statePersistenceService,
                                                                                      pinnedTabsManager: pinnedTabsManager,
                                                                                      windowManager: windowManager,
                                                                                      passwordManagerCoordinator: passwordManagerCoordinator)
        self.stateRestorationManager = AppStateRestorationManager(dependencyProvider: stateRestorationManagerDependencies,
                                                                  shouldRestorePreviousSession: StartupPreferences().restorePreviousSession)

        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.recentlyClosedCoordinator = recentlyClosedCoordinator
        self.fireCoordinator = fireCoordinator
        self.downloadListCoordinator = downloadListCoordinator
        self.pinnedTabsManagerValue = pinnedTabsManager
    }

}
