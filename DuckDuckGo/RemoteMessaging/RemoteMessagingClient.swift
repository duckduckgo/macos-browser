//
//  RemoteMessagingClient.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Combine
import Common
import Configuration
import Foundation
import BrowserServicesKit
import Persistence
import PixelKit
import RemoteMessaging

protocol RemoteMessagingStoreProviding {
    func makeRemoteMessagingStore(database: CoreDataDatabase, availabilityProvider: RemoteMessagingAvailabilityProviding) -> RemoteMessagingStoring
}

struct DefaultRemoteMessagingStoreProvider: RemoteMessagingStoreProviding {
    func makeRemoteMessagingStore(database: CoreDataDatabase, availabilityProvider: RemoteMessagingAvailabilityProviding) -> RemoteMessagingStoring {
        RemoteMessagingStore(
            database: database,
            notificationCenter: .default,
            errorEvents: RemoteMessagingStoreErrorHandling(),
            remoteMessagingAvailabilityProvider: availabilityProvider
        )
    }
}

final class RemoteMessagingClient: RemoteMessagingProcessing {

    struct Constants {
        static let minimumConfigurationRefreshInterval: TimeInterval = 60 * 30
        static let endpoint: URL = {
#if DEBUG
            URL(string: "https://raw.githubusercontent.com/duckduckgo/remote-messaging-config/main/samples/ios/sample1.json")!
#else
            URL(string: "https://staticcdn.duckduckgo.com/remotemessaging/config/v1/macos-config.json")!
#endif
        }()
    }

    let database: CoreDataDatabase
    let endpoint: URL = Constants.endpoint
    let configFetcher: RemoteMessagingConfigFetching
    let configMatcherProvider: RemoteMessagingConfigMatcherProviding
    let remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding
    private(set) var store: RemoteMessagingStoring?

    convenience init(
        database: CoreDataDatabase,
        bookmarksDatabase: CoreDataDatabase,
        appearancePreferences: AppearancePreferences,
        pinnedTabsManager: PinnedTabsManager,
        internalUserDecider: InternalUserDecider,
        configurationStore: ConfigurationStoring,
        remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding,
        remoteMessagingStoreProvider: RemoteMessagingStoreProviding = DefaultRemoteMessagingStoreProvider()
    ) {
        let provider = RemoteMessagingConfigMatcherProvider(
            bookmarksDatabase: bookmarksDatabase,
            appearancePreferences: appearancePreferences,
            pinnedTabsManager: pinnedTabsManager,
            internalUserDecider: internalUserDecider
        )
        self.init(
            database: database,
            configMatcherProvider: provider,
            configurationStore: configurationStore,
            remoteMessagingAvailabilityProvider: remoteMessagingAvailabilityProvider
        )
    }

    convenience init(
        database: CoreDataDatabase,
        configMatcherProvider: RemoteMessagingConfigMatcherProviding,
        configurationStore: ConfigurationStoring,
        remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding,
        remoteMessagingStoreProvider: RemoteMessagingStoreProviding = DefaultRemoteMessagingStoreProvider()
    ) {
        let configFetcher = RemoteMessagingConfigFetcher(
            configurationFetcher: ConfigurationFetcher(
                store: configurationStore,
                urlSession: .session(),
                eventMapping: ConfigurationManager.configurationDebugEvents
            ),
            configurationStore: configurationStore
        )

        self.init(
            database: database,
            configFetcher: configFetcher,
            configMatcherProvider: configMatcherProvider,
            remoteMessagingAvailabilityProvider: remoteMessagingAvailabilityProvider,
            remoteMessagingStoreProvider: remoteMessagingStoreProvider
        )
    }

    /**
     * This designated initializer is used in unit tests where `configFetcher` needs mocking.
     */
    init(
        database: CoreDataDatabase,
        configFetcher: RemoteMessagingConfigFetching,
        configMatcherProvider: RemoteMessagingConfigMatcherProviding,
        remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding,
        remoteMessagingStoreProvider: RemoteMessagingStoreProviding = DefaultRemoteMessagingStoreProvider()
    ) {
        self.database = database
        self.configFetcher = configFetcher
        self.configMatcherProvider = configMatcherProvider
        self.remoteMessagingAvailabilityProvider = remoteMessagingAvailabilityProvider
        self.remoteMessagingStoreProvider = remoteMessagingStoreProvider

        subscribeToFeatureFlagChanges()

        if remoteMessagingAvailabilityProvider.isRemoteMessagingAvailable {
            initializeDatabaseIfNeeded()
        }
    }

    /**
     * Starts a periodical remote messages refresh.
     *
     * It checks for the feature flag (via `remoteMessagingAvailabilityProvider`) before starting a timer
     * and if it finds the feature flag to be disabled, it actually ensures that timer is disabled and
     * returns early.
     *
     * Starting the refresh timer can be forced – used when called from `isRemoteMessagingAvailablePublisher`
     * event handler, where the new value (true) is emitted but it's not yet available from
     * `remoteMessagingAvailabilityProvider.isRemoteMessagingAvailable` property getter.
     */
    func startRefreshingRemoteMessages(force: Bool = false) {
        guard force || remoteMessagingAvailabilityProvider.isRemoteMessagingAvailable else {
            stopRefreshingRemoteMessages()
            return
        }

        scheduledRefreshCancellable = Timer.publish(every: Constants.minimumConfigurationRefreshInterval, on: .main, in: .default)
            .autoconnect()
            .prepend(Date())
            .asVoid()
            .sink { [weak self] in
                self?.refreshRemoteMessages()
            }
    }

    /// It's public in order to allow refreshing on demand via Debug menu. Otherwise it shouldn't be called from outside.
    func refreshRemoteMessages() {
        guard NSApp.runType.requiresEnvironment else {
            return
        }
        Task {
            guard let store else {
                return
            }
            try? await fetchAndProcess(using: store)
        }
    }

    private func stopRefreshingRemoteMessages() {
        scheduledRefreshCancellable?.cancel()
    }

    private func subscribeToFeatureFlagChanges() {
        featureFlagCancellable = remoteMessagingAvailabilityProvider.isRemoteMessagingAvailablePublisher
            .sink { [weak self] isRemoteMessagingAvailable in
                if isRemoteMessagingAvailable {
                    self?.initializeDatabaseIfNeeded()
                    self?.startRefreshingRemoteMessages(force: true)
                } else {
                    self?.stopRefreshingRemoteMessages()
                }
            }
    }

    private func initializeDatabaseIfNeeded() {
        guard !isRemoteMessagingDatabaseLoaded else {
            return
        }

        if NSApplication.runType.requiresEnvironment {
            database.loadStore { context, error in
                guard context != nil else {
                    if let error = error {
                        PixelKit.fire(DebugEvent(GeneralPixel.syncMetadataCouldNotLoadDatabase, error: error))
                    } else {
                        PixelKit.fire(DebugEvent(GeneralPixel.syncMetadataCouldNotLoadDatabase))
                    }

                    Thread.sleep(forTimeInterval: 1)
                    fatalError("Could not create Remote Messaging database stack: \(error?.localizedDescription ?? "err")")
                }
            }
        }

        store = remoteMessagingStoreProvider.makeRemoteMessagingStore(
            database: database,
            availabilityProvider: remoteMessagingAvailabilityProvider
        )

        isRemoteMessagingDatabaseLoaded = true
    }

    // Publicly accessible for use in RemoteMessagingDebugMenu
    private(set) var isRemoteMessagingDatabaseLoaded = false
    private let remoteMessagingStoreProvider: RemoteMessagingStoreProviding
    private var scheduledRefreshCancellable: AnyCancellable?
    private var featureFlagCancellable: AnyCancellable?
}
