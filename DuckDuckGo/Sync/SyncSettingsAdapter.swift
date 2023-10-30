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

extension SettingsProvider.Setting {
    static let favoritesDisplayMode = SettingsProvider.Setting(key: "favorites_display_mode")
}

final class SyncSettingsAdapter {

    private(set) var provider: SettingsProvider?
    private(set) var emailManager: EmailManager?
    let syncDidCompletePublisher: AnyPublisher<Void, Never>

    init() {
        syncDidCompletePublisher = syncDidCompleteSubject.eraseToAnyPublisher()
    }

    func setUpProviderIfNeeded(metadataDatabase: CoreDataDatabase, metadataStore: SyncMetadataStore) {
        guard provider == nil else {
            return
        }
        let emailManager = EmailManager()

        let provider = SettingsProvider(
            metadataDatabase: metadataDatabase,
            metadataStore: metadataStore,
            settingsHandlers: [FavoritesDisplayModeSyncHandler(), EmailProtectionSyncHandler(emailManager: emailManager)],
            syncDidUpdateData: { [weak self] changes in
                if changes != nil {
                    self?.syncDidCompleteSubject.send()
                }
            }
        )

        syncErrorCancellable = provider.syncErrorPublisher
            .sink { error in
                switch error {
                case let syncError as SyncError:
                    Pixel.fire(.debug(event: .syncSettingsFailed, error: syncError))
                case let settingsMetadataError as SettingsSyncMetadataSaveError:
                    let underlyingError = settingsMetadataError.underlyingError
                    let processedErrors = CoreDataErrorsParser.parse(error: underlyingError as NSError)
                    let params = processedErrors.errorPixelParameters
                    Pixel.fire(.debug(event: .syncSettingsMetadataUpdateFailed, error: underlyingError), withAdditionalParameters: params)
                default:
                    let nsError = error as NSError
                    if nsError.domain != NSURLErrorDomain {
                        let processedErrors = CoreDataErrorsParser.parse(error: error as NSError)
                        let params = processedErrors.errorPixelParameters
                        Pixel.fire(.debug(event: .syncSettingsFailed, error: error), withAdditionalParameters: params)
                    }
                }
                os_log(.error, log: OSLog.sync, "Settings Sync error: %{public}s", String(reflecting: error))
            }

        self.provider = provider
        self.emailManager = emailManager
    }

    private var syncDidCompleteSubject = PassthroughSubject<Void, Never>()
    private var syncErrorCancellable: AnyCancellable?
}
