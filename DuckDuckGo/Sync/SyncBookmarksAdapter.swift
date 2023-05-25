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

import Combine
import Common
import DDGSync
import Persistence
import SyncDataProviders

final class SyncBookmarksAdapter {

    private(set) var provider: BookmarksProvider?

    func setUpProviderIfNeeded(database: CoreDataDatabase, metadataStore: SyncMetadataStore) {
        guard provider == nil else {
            return
        }

        let provider = BookmarksProvider(
            database: database,
            metadataStore: metadataStore,
            reloadBookmarksAfterSync: LocalBookmarkManager.shared.loadBookmarks
        )

        syncErrorCancellable = provider.syncErrorPublisher
            .sink { error in
                switch error {
                case let syncError as SyncError:
                    Pixel.fire(.debug(event: .syncBookmarksFailed, error: syncError))
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
    }

    private var syncErrorCancellable: AnyCancellable?
}
