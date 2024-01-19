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

public class BookmarksFaviconsFetcherErrorHandler: EventMapping<BookmarksFaviconsFetcherError> {

    public init() {
        super.init { event, _, _, _ in
            Pixel.fire(.debug(event: .bookmarksFaviconsFetcherFailed, error: event.underlyingError))
        }
    }

    override init(mapping: @escaping EventMapping<BookmarksFaviconsFetcherError>.Mapping) {
        fatalError("Use init()")
    }
}

final class SyncBookmarksAdapter {

    private(set) var provider: BookmarksProvider?
    let databaseCleaner: BookmarkDatabaseCleaner

    @Published
    var isFaviconsFetchingEnabled: Bool = UserDefaultsWrapper(key: .syncIsFaviconsFetcherEnabled, defaultValue: false).wrappedValue {
        didSet {
            var udWrapper = UserDefaultsWrapper(key: .syncIsFaviconsFetcherEnabled, defaultValue: false)
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

    @UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false)
    private var isSyncBookmarksPaused: Bool {
        didSet {
            NotificationCenter.default.post(name: SyncPreferences.Consts.syncPausedStateChanged, object: nil)
        }
    }

    @UserDefaultsWrapper(key: .syncBookmarksPausedErrorDisplayed, defaultValue: false)
    private var didShowBookmarksSyncPausedError: Bool

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
                LocalBookmarkManager.shared.loadBookmarks()
                self?.isSyncBookmarksPaused = false
                self?.didShowBookmarksSyncPausedError = false
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
            provider.lastSyncTimestamp = nil
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
            Pixel.fire(.debug(event: .bookmarksFaviconsFetcherStateStoreInitializationFailed, error: error))
            os_log(.error, log: OSLog.sync, "Failed to initialize BookmarksFaviconsFetcherStateStore: %{public}s", String(reflecting: error))
            return nil
        }

        return BookmarksFaviconsFetcher(
            database: database,
            stateStore: stateStore,
            fetcher: FaviconFetcher(),
            faviconStore: FaviconManager.shared,
            errorEvents: BookmarksFaviconsFetcherErrorHandler(),
            log: .sync
        )
    }

    private func bindSyncErrorPublisher(_ provider: BookmarksProvider) {
        syncErrorCancellable = provider.syncErrorPublisher
            .sink { [weak self] error in
                switch error {
                case let syncError as SyncError:
                    Pixel.fire(.debug(event: .syncBookmarksFailed, error: syncError))
                    switch syncError {
                    case .unexpectedStatusCode(409):
                        // If bookmarks count limit has been exceeded
                        self?.isSyncBookmarksPaused = true
                        Pixel.fire(.syncBookmarksCountLimitExceededDaily, limitTo: .dailyFirst)
                        self?.showSyncPausedAlert()
                    case .unexpectedStatusCode(413):
                        // If bookmarks request size limit has been exceeded
                        self?.isSyncBookmarksPaused = true
                        Pixel.fire(.syncBookmarksRequestSizeLimitExceededDaily, limitTo: .dailyFirst)
                        self?.showSyncPausedAlert()
                    default:
                        break
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
    }

    private func handleFavoritesAfterDisablingSync() {
        bookmarkManager.handleFavoritesAfterDisablingSync()
        if appearancePreferences.favoritesDisplayMode.isDisplayUnified {
            appearancePreferences.favoritesDisplayMode = .displayNative(.desktop)
        }
    }

    private func showSyncPausedAlert() {
        guard !didShowBookmarksSyncPausedError else { return }
        Task {
            await MainActor.run {
                let alert = NSAlert.syncBookmarksPaused()
                let response = alert.runModal()
                didShowBookmarksSyncPausedError = true

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

    private var syncErrorCancellable: AnyCancellable?
    private let bookmarkManager: BookmarkManager
    private let database: CoreDataDatabase
    private let appearancePreferences: AppearancePreferences
    private var faviconsFetcher: BookmarksFaviconsFetcher?
}
