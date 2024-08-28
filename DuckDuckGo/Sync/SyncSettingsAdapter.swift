//
//  SyncSettingsAdapter.swift
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
import BrowserServicesKit
import Combine
import Common
import DDGSync
import Persistence
import SyncDataProviders
import PixelKit

extension SettingsProvider.Setting {
    static let favoritesDisplayMode = SettingsProvider.Setting(key: "favorites_display_mode")
}

final class SyncSettingsAdapter {

    private(set) var provider: SettingsProvider?
    private(set) var emailManager: EmailManager?
    let syncDidCompletePublisher: AnyPublisher<Void, Never>
    private let syncErrorHandler: SyncErrorHandling

    init(syncErrorHandler: SyncErrorHandling) {
        syncDidCompletePublisher = syncDidCompleteSubject.eraseToAnyPublisher()
        self.syncErrorHandler = syncErrorHandler
    }

    func setUpProviderIfNeeded(
        metadataDatabase: CoreDataDatabase,
        metadataStore: SyncMetadataStore,
        metricsEventsHandler: EventMapping<MetricsEvent>? = nil
    ) {
        guard provider == nil else {
            return
        }
        let emailManager = EmailManager()

        let provider = SettingsProvider(
            metadataDatabase: metadataDatabase,
            metadataStore: metadataStore,
            settingsHandlers: [FavoritesDisplayModeSyncHandler(), EmailProtectionSyncHandler(emailManager: emailManager)],
            metricsEvents: metricsEventsHandler,
            syncDidUpdateData: { [weak self] in
                self?.syncDidCompleteSubject.send()
            }
        )

        syncErrorCancellable = provider.syncErrorPublisher
            .sink { [weak self] error in
                self?.syncErrorHandler.handleSettingsError(error)
            }

        self.provider = provider
        self.emailManager = emailManager
    }

    private var syncDidCompleteSubject = PassthroughSubject<Void, Never>()
    private var syncErrorCancellable: AnyCancellable?
}
