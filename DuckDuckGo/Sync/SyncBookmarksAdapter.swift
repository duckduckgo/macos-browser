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

final class SyncBookmarksAdapter {

    private(set) var provider: BookmarksProvider?
    let databaseCleaner: BookmarkDatabaseCleaner
    var shouldResetBookmarksSyncTimestamp: Bool = false {
        willSet {
            assert(provider == nil, "Setting this value has no effect after provider has been instantiated")
        }
    }

    @Published
    var isFaviconsFetchingEnabled: Bool = UserDefaultsWrapper(key: .syncAutomaticallyFetchFavicons, defaultValue: false).wrappedValue {
        didSet {
            var udWrapper = UserDefaultsWrapper(key: .syncAutomaticallyFetchFavicons, defaultValue: false)
            udWrapper.wrappedValue = isFaviconsFetchingEnabled
            if isFaviconsFetchingEnabled {
                faviconsFetcher?.initializeFetcherState()
            } else {
                faviconsFetcher?.cancelOngoingFetchingIfNeeded()
            }
        }
    }

    init(
        database: CoreDataDatabase,
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        appearancePreferences: AppearancePreferences = .shared
    ) {
        self.database = database
        self.bookmarkManager = bookmarkManager
        self.appearancePreferences = appearancePreferences
        databaseCleaner = BookmarkDatabaseCleaner(
            bookmarkDatabase: database,
            errorEvents: BookmarksCleanupErrorHandling(),
            log: .bookmarks
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
    func setUpProviderIfNeeded(database: CoreDataDatabase, metadataStore: SyncMetadataStore) {
        guard provider == nil else {
            return
        }

        let faviconsFetcher = BookmarksFaviconsFetcher(
            database: database,
            stateStore: BookmarkFaviconsFetcherStateStore(applicationSupportURL: .sandboxApplicationSupportURL),
            fetcher: FaviconFetcher(),
            store: FaviconManager.shared,
            log: .sync
        )

        let provider = BookmarksProvider(
            database: database,
            metadataStore: metadataStore,
            syncDidUpdateData: { [weak self] in
                LocalBookmarkManager.shared.loadBookmarks()
                self?.isSyncBookmarksPaused = false
            },
            syncDidFinish: { [weak self] faviconsFetcherInput in
                if self?.isFaviconsFetchingEnabled == true {
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

        if shouldResetBookmarksSyncTimestamp {
            provider.lastSyncTimestamp = nil
        }

        syncErrorCancellable = provider.syncErrorPublisher
            .sink { [weak self] error in
                switch error {
                case let syncError as SyncError:
                    Pixel.fire(.debug(event: .syncBookmarksFailed, error: syncError))
                    // If bookmarks count limit has been exceeded
                    if syncError == .unexpectedStatusCode(409) {
                        self?.isSyncBookmarksPaused = true
                        Pixel.fire(.syncBookmarksCountLimitExceededDaily, limitTo: .dailyFirst)
                    }
                    // If bookmarks request size limit has been exceeded
                    if syncError == .unexpectedStatusCode(413) {
                        self?.isSyncBookmarksPaused = true
                        Pixel.fire(.syncBookmarksRequestSizeLimitExceededDaily, limitTo: .dailyFirst)
                    }
                default:
                    let nsError = error as NSError
                    if nsError.domain != NSURLErrorDomain {
                        let processedErrors = CoreDataErrorsParser.parse(error: error as NSError)
                        let params = processedErrors.errorPixelParameters
                        Pixel.fire(.debug(event: .syncBookmarksFailed, error: error), withAdditionalParameters: params)
                    }
                }
                os_log(.error, log: OSLog.sync, "Bookmarks Sync error: %{public}s", String(reflecting: error))
            }

        self.provider = provider
        self.faviconsFetcher = faviconsFetcher
    }

    private func handleFavoritesAfterDisablingSync() {
        bookmarkManager.handleFavoritesAfterDisablingSync()
        if appearancePreferences.favoritesDisplayMode.isDisplayUnified {
            appearancePreferences.favoritesDisplayMode = .displayNative(.desktop)
        }
    }

    @UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false)
    private var isSyncBookmarksPaused: Bool {
        didSet {
            NotificationCenter.default.post(name: SyncPreferences.Consts.syncPausedStateChanged, object: nil)
        }
    }

    private var syncErrorCancellable: AnyCancellable?
    private let bookmarkManager: BookmarkManager
    private let database: CoreDataDatabase
    private let appearancePreferences: AppearancePreferences
    private var faviconsFetcher: BookmarksFaviconsFetcher?
}
