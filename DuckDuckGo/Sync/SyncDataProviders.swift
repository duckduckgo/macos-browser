//
//  SyncDataProviders.swift
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

import BrowserServicesKit
import Combine
import Common
import DDGSync
import Persistence
import SyncDataProviders

final class SyncDataProviders: DataProvidersSource {
    public let bookmarksAdapter: SyncBookmarksAdapter
    public let credentialsAdapter: SyncCredentialsAdapter
    public let settingsAdapter: SyncSettingsAdapter
    public let tabsAdapter: SyncTabsAdapter

    func makeDataProviders() -> [DataProviding] {
        initializeMetadataDatabaseIfNeeded()
        guard let syncMetadata else {
            assertionFailure("Sync Metadata not initialized")
            return []
        }

        bookmarksAdapter.setUpProviderIfNeeded(database: bookmarksDatabase, metadataStore: syncMetadata)
        credentialsAdapter.setUpProviderIfNeeded(secureVaultFactory: secureVaultFactory, metadataStore: syncMetadata)
        settingsAdapter.setUpProviderIfNeeded(metadataDatabase: syncMetadataDatabase.db, metadataStore: syncMetadata)
        tabsAdapter.setUpProviderIfNeeded(metadataStore: syncMetadata)

        let providers: [Any] = [
            bookmarksAdapter.provider as Any,
            credentialsAdapter.provider as Any,
            settingsAdapter.provider as Any,
            tabsAdapter.provider as Any
        ]

        return providers.compactMap { $0 as? DataProviding }
    }

    func setUpDatabaseCleaners(syncService: DDGSync) {
        bookmarksAdapter.databaseCleaner.isSyncActive = { [weak syncService] in
            syncService?.authState == .active
        }

        credentialsAdapter.databaseCleaner.isSyncActive = { [weak syncService] in
            syncService?.authState == .active
        }

        let syncAuthStateDidChangePublisher = syncService.authStatePublisher
            .dropFirst()
            .map { $0 == .inactive }
            .removeDuplicates()

        syncAuthStateDidChangeCancellable = syncAuthStateDidChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncDisabled in
                self?.bookmarksAdapter.cleanUpDatabaseAndUpdateSchedule(shouldEnable: isSyncDisabled)
                self?.credentialsAdapter.cleanUpDatabaseAndUpdateSchedule(shouldEnable: isSyncDisabled)
            }

        if syncService.authState == .inactive {
            bookmarksAdapter.cleanUpDatabaseAndUpdateSchedule(shouldEnable: true)
            credentialsAdapter.cleanUpDatabaseAndUpdateSchedule(shouldEnable: true)
        }

        let deviceIdPublisher = syncService.authStatePublisher
            .compactMap { [weak syncService] _ in syncService?.account?.deviceId }
            .removeDuplicates()

        syncDeviceNameCancellable = deviceIdPublisher
            .sink { [weak self] deviceId in
                self?.tabsAdapter.deviceId = deviceId
            }
    }

    init(bookmarksDatabase: CoreDataDatabase, secureVaultFactory: AutofillVaultFactory = AutofillSecureVaultFactory) {
        self.bookmarksDatabase = bookmarksDatabase
        self.secureVaultFactory = secureVaultFactory
        bookmarksAdapter = SyncBookmarksAdapter(database: bookmarksDatabase)
        credentialsAdapter = SyncCredentialsAdapter(secureVaultFactory: secureVaultFactory)
        settingsAdapter = SyncSettingsAdapter()
        tabsAdapter = SyncTabsAdapter()
    }

    private func initializeMetadataDatabaseIfNeeded() {
        guard !isSyncMetadaDatabaseLoaded else {
            return
        }

        syncMetadataDatabase.db.loadStore { context, error in
            guard context != nil else {
                if let error = error {
                    Pixel.fire(.debug(event: .syncMetadataCouldNotLoadDatabase, error: error))
                } else {
                    Pixel.fire(.debug(event: .syncMetadataCouldNotLoadDatabase))
                }

                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not create Sync Metadata database stack: \(error?.localizedDescription ?? "err")")
            }
        }
        syncMetadata = LocalSyncMetadataStore(database: syncMetadataDatabase.db)
        isSyncMetadaDatabaseLoaded = true
    }

    private var isSyncMetadaDatabaseLoaded: Bool = false
    private var syncMetadata: SyncMetadataStore?
    private var syncAuthStateDidChangeCancellable: AnyCancellable?
    private var syncDeviceNameCancellable: AnyCancellable?

    private let syncMetadataDatabase: SyncMetadataDatabase = SyncMetadataDatabase()
    private let bookmarksDatabase: CoreDataDatabase
    private let secureVaultFactory: AutofillVaultFactory
}
