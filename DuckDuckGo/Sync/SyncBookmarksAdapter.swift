//
//  SyncBookmarksAdapter.swift
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

import Bookmarks
import Combine
import Common
import DDGSync
import Persistence
import SyncDataProviders
import PixelKit
import os.log

public class BookmarksFaviconsFetcherErrorHandler: EventMapping<BookmarksFaviconsFetcherError> {

    public init() {
        super.init { event, _, _, _ in
            PixelKit.fire(DebugEvent(GeneralPixel.bookmarksFaviconsFetcherFailed, error: event.underlyingError))
        }
    }

    override init(mapping: @escaping EventMapping<BookmarksFaviconsFetcherError>.Mapping) {
        fatalError("Use init()")
    }
}

final class SyncBookmarksAdapter {

    private(set) var provider: BookmarksProvider?
    let databaseCleaner: BookmarkDatabaseCleaner
    let syncErrorHandler: SyncErrorHandling

    @Published
    var isFaviconsFetchingEnabled: Bool = UserDefaultsWrapper(key: .syncIsFaviconsFetcherEnabled, defaultValue: false).wrappedValue {
        didSet {
            let udWrapper = UserDefaultsWrapper(key: .syncIsFaviconsFetcherEnabled, defaultValue: false)
            udWrapper.wrappedValue = isFaviconsFetchingEnabled
            if isFaviconsFetchingEnabled {
                faviconsFetcher?.initializeFetcherState()
            } else {
                faviconsFetcher?.cancelOngoingFetchingIfNeeded()
            }
        }
    }

    @UserDefaultsWrapper(key: .syncIsEligibleForFaviconsFetcherOnboarding, defaultValue: false)
    var isEligibleForFaviconsFetcherOnboarding: Bool

    @UserDefaultsWrapper(key: .syncDidMigrateToImprovedListsHandling, defaultValue: false)
    private var didMigrateToImprovedListsHandling: Bool

    init(
        database: CoreDataDatabase,
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        appearancePreferences: AppearancePreferences = .shared,
        syncErrorHandler: SyncErrorHandling
    ) {
        self.database = database
        self.bookmarkManager = bookmarkManager
        self.appearancePreferences = appearancePreferences
        self.syncErrorHandler = syncErrorHandler
        databaseCleaner = BookmarkDatabaseCleaner(
            bookmarkDatabase: database,
            errorEvents: BookmarksCleanupErrorHandling()
        )
    }

    func cleanUpDatabaseAndUpdateSchedule(shouldEnable: Bool) {
        databaseCleaner.cleanUpDatabaseNow()
        if shouldEnable {
            databaseCleaner.scheduleRegularCleaning()
            handleFavoritesAfterDisablingSync()
            isFaviconsFetchingEnabled = false
        } else {
            databaseCleaner.cancelCleaningSchedule()
        }
    }

    @MainActor
    func setUpProviderIfNeeded(
        database: CoreDataDatabase,
        metadataStore: SyncMetadataStore,
        metricsEventsHandler: EventMapping<MetricsEvent>? = nil
    ) {
        guard provider == nil else {
            return
        }

        let faviconsFetcher = setUpFaviconsFetcher()

        let provider = BookmarksProvider(
            database: database,
            metadataStore: metadataStore,
            metricsEvents: metricsEventsHandler,
            syncDidUpdateData: { [weak self] in
                self?.syncErrorHandler.syncBookmarksSucceded()
                guard let manager = self?.bookmarkManager as? LocalBookmarkManager else { return }
                manager.loadBookmarks()
            },
            syncDidFinish: { [weak self] faviconsFetcherInput in
                if let faviconsFetcher, self?.isFaviconsFetchingEnabled == true {
                    if let faviconsFetcherInput {
                        faviconsFetcher.updateBookmarkIDs(
                            modified: faviconsFetcherInput.modifiedBookmarksUUIDs,
                            deleted: faviconsFetcherInput.deletedBookmarksUUIDs
                        )
                    }
                    faviconsFetcher.startFetching()
                }
            }
        )

        if !didMigrateToImprovedListsHandling {
            didMigrateToImprovedListsHandling = true
            provider.updateSyncTimestamps(server: nil, local: nil)
        }

        bindSyncErrorPublisher(provider)

        self.provider = provider
        self.faviconsFetcher = faviconsFetcher
    }

    private func setUpFaviconsFetcher() -> BookmarksFaviconsFetcher? {
        let stateStore: BookmarksFaviconsFetcherStateStore
        do {
            stateStore = try BookmarksFaviconsFetcherStateStore(applicationSupportURL: URL.sandboxApplicationSupportURL)
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.bookmarksFaviconsFetcherStateStoreInitializationFailed, error: error))
            Logger.sync.error("Failed to initialize BookmarksFaviconsFetcherStateStore: \(String(reflecting: error), privacy: .public)")
            return nil
        }

        return BookmarksFaviconsFetcher(
            database: database,
            stateStore: stateStore,
            fetcher: FaviconFetcher(),
            faviconStore: FaviconManager.shared,
            errorEvents: BookmarksFaviconsFetcherErrorHandler()
        )
    }

    private func bindSyncErrorPublisher(_ provider: BookmarksProvider) {
        syncErrorCancellable = provider.syncErrorPublisher
            .sink { [weak self] error in
                self?.syncErrorHandler.handleBookmarkError(error)
            }
    }

    private func handleFavoritesAfterDisablingSync() {
        bookmarkManager.handleFavoritesAfterDisablingSync()
        if appearancePreferences.favoritesDisplayMode.isDisplayUnified {
            appearancePreferences.favoritesDisplayMode = .displayNative(.desktop)
        }
    }

    private var syncErrorCancellable: AnyCancellable?
    private let bookmarkManager: BookmarkManager
    private let database: CoreDataDatabase
    private let appearancePreferences: AppearancePreferences
    private var faviconsFetcher: BookmarksFaviconsFetcher?
}
