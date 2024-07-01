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

import Combine
import Configuration
import Foundation
import BrowserServicesKit
import Persistence
import PixelKit
import RemoteMessaging

final class RemoteMessagingClient: RemoteMessagingProcessing {

    struct Constants {
        static let minimumConfigurationRefreshInterval: TimeInterval = 60 * 30
        static let endpoint: URL = {
#if DEBUG
            URL(string: "https://staticcdn.kapusta.cc/macos-desktop-browser/remote-messaging-config.json")!
#else
            URL(string: "https://staticcdn.duckduckgo.com/remotemessaging/config/v1/ios-config.json")!
#endif
        }()
    }

    let endpoint: URL = Constants.endpoint
    let configurationFetcher: RemoteMessagingConfigFetching
    let configMatcherProvider: RemoteMessagingConfigMatcherProviding
    let privacyConfigurationManager: PrivacyConfigurationManaging
    private(set) var store: RemoteMessagingStore?

    var isRemoteMessagingEnabled: Bool {
        privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .remoteMessaging)
    }

    convenience init(
        database: RemoteMessagingDatabase,
        bookmarksDatabase: CoreDataDatabase,
        appearancePreferences: AppearancePreferences,
        internalUserDecider: InternalUserDecider,
        configurationStore: ConfigurationStoring,
        privacyConfigurationManager: PrivacyConfigurationManaging
    ) {
        let provider = RemoteMessagingConfigMatcherProvider(
            bookmarksDatabase: bookmarksDatabase,
            appearancePreferences: appearancePreferences,
            internalUserDecider: internalUserDecider
        )
        self.init(
            database: database,
            internalUserDecider: internalUserDecider,
            configMatcherProvider: provider,
            configurationStore: configurationStore,
            privacyConfigurationManager: privacyConfigurationManager
        )
    }

    init(
        database: RemoteMessagingDatabase,
        internalUserDecider: InternalUserDecider,
        configMatcherProvider: RemoteMessagingConfigMatcherProviding,
        configurationStore: ConfigurationStoring,
        privacyConfigurationManager: PrivacyConfigurationManaging
    ) {
        self.database = database
        self.internalUserDecider = internalUserDecider
        self.configurationFetcher = RemoteMessagingConfigFetcher(
            configurationFetcher: ConfigurationFetcher(store: configurationStore, urlSession: .session(), log: .remoteMessaging, eventMapping: nil),
            configurationStore: ConfigurationStore.shared
        )
        self.configMatcherProvider = configMatcherProvider
        self.privacyConfigurationManager = privacyConfigurationManager

        subscribeToInternalUserFlagChangesIfNeeded()
    }

    private func subscribeToInternalUserFlagChangesIfNeeded() {
        guard !internalUserDecider.isInternalUser else {
            return
        }

        internalUserCancellable = internalUserDecider.isInternalUserPublisher
            .filter { $0 }
            .prefix(1)
            .sink { [weak self] isInternalUser in
                if isInternalUser {
                    self?.initializeDatabaseIfNeeded()
                    self?.startRefreshingRemoteMessages()
                }
            }
    }

    func initializeDatabaseIfNeeded() {
        guard internalUserDecider.isInternalUser else {
            return
        }
        guard !isRemoteMessagingDatabaseLoaded else {
            return
        }

        database.db.loadStore { context, error in
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
        store = RemoteMessagingStore(
            database: database.db,
            errorEvents: RemoteMessagingStoreErrorHandling(),
            privacyConfigurationManager: privacyConfigurationManager
        )
        isRemoteMessagingDatabaseLoaded = true
    }

    func startRefreshingRemoteMessages() {
        guard internalUserDecider.isInternalUser else {
            timerCancellable?.cancel()
            return
        }
        guard isRemoteMessagingEnabled else {
            timerCancellable?.cancel()
            return
        }
        timerCancellable = Timer.publish(every: Constants.minimumConfigurationRefreshInterval, on: .main, in: .default)
            .autoconnect()
            .prepend(Date())
            .asVoid()
            .sink { [weak self] in
                self?.refreshRemoteMessages()
            }
    }

    private let database: RemoteMessagingDatabase
    private let internalUserDecider: InternalUserDecider
    private var isRemoteMessagingDatabaseLoaded = false
    private var timerCancellable: AnyCancellable?
    private var internalUserCancellable: AnyCancellable?

    @UserDefaultsWrapper(key: .lastRemoteMessagingRefreshDate, defaultValue: .distantPast)
    static private var lastRemoteMessagingRefreshDate: Date

    private func refreshRemoteMessages() {
        guard let store else {
            return
        }

        Task {
            try? await fetchAndProcess(using: store)
        }
    }
}
