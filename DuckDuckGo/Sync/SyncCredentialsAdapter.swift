//
//  SyncCredentialsAdapter.swift
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

final class SyncCredentialsAdapter {

    private(set) var provider: CredentialsProvider?
    let databaseCleaner: CredentialsDatabaseCleaner
    let syncDidCompletePublisher: AnyPublisher<Void, Never>

    @UserDefaultsWrapper(key: .syncCredentialsPaused, defaultValue: false)
    private var isSyncCredentialsPaused: Bool {
        didSet {
            NotificationCenter.default.post(name: SyncPreferences.Consts.syncPausedStateChanged, object: nil)
        }
    }

    @UserDefaultsWrapper(key: .syncCredentialsPausedErrorDisplayed, defaultValue: false)
    private var didShowCredentialsSyncPausedError: Bool

    init(secureVaultFactory: AutofillVaultFactory = AutofillSecureVaultFactory) {
        syncDidCompletePublisher = syncDidCompleteSubject.eraseToAnyPublisher()
        databaseCleaner = CredentialsDatabaseCleaner(
            secureVaultFactory: secureVaultFactory,
            secureVaultErrorReporter: SecureVaultErrorReporter.shared,
            errorEvents: CredentialsCleanupErrorHandling(),
            log: .passwordManager
        )
    }

    func cleanUpDatabaseAndUpdateSchedule(shouldEnable: Bool) {
        databaseCleaner.cleanUpDatabaseNow()
        if shouldEnable {
            databaseCleaner.scheduleRegularCleaning()
        } else {
            databaseCleaner.cancelCleaningSchedule()
        }
    }

    func setUpProviderIfNeeded(secureVaultFactory: AutofillVaultFactory, metadataStore: SyncMetadataStore) {
        guard provider == nil else {
            return
        }

        do {
            let provider = try CredentialsProvider(
                secureVaultFactory: secureVaultFactory,
                secureVaultErrorReporter: SecureVaultErrorReporter.shared,
                metadataStore: metadataStore,
                syncDidUpdateData: { [weak self] in
                    self?.syncDidCompleteSubject.send()
                    self?.isSyncCredentialsPaused = false
                    self?.didShowCredentialsSyncPausedError = false
                }
            )

            syncErrorCancellable = provider.syncErrorPublisher
                .sink { [weak self] error in
                    switch error {
                    case let syncError as SyncError:
                        Pixel.fire(.debug(event: .syncCredentialsFailed, error: syncError))
                        switch syncError {
                        case .unexpectedStatusCode(409):
                            // If credentials count limit has been exceeded
                            self?.isSyncCredentialsPaused = true
                            Pixel.fire(.syncCredentialsCountLimitExceededDaily, limitTo: .dailyFirst)
                            self?.showSyncPausedAlert()
                        case .unexpectedStatusCode(413):
                            // If credentials request size limit has been exceeded
                            self?.isSyncCredentialsPaused = true
                            Pixel.fire(.syncCredentialsRequestSizeLimitExceededDaily, limitTo: .dailyFirst)
                            self?.showSyncPausedAlert()
                        default:
                            break
                        }
                    default:
                        let nsError = error as NSError
                        if nsError.domain != NSURLErrorDomain {
                            let processedErrors = CoreDataErrorsParser.parse(error: error as NSError)
                            let params = processedErrors.errorPixelParameters
                            Pixel.fire(.debug(event: .syncCredentialsFailed, error: error), withAdditionalParameters: params)
                        }
                    }
                    os_log(.error, log: OSLog.sync, "Credentials Sync error: %{public}s", String(reflecting: error))
                }

            self.provider = provider

        } catch let error as NSError {
            let processedErrors = CoreDataErrorsParser.parse(error: error)
            let params = processedErrors.errorPixelParameters
            Pixel.fire(.debug(event: .syncCredentialsProviderInitializationFailed, error: error), withAdditionalParameters: params)
        }
    }

    private func showSyncPausedAlert() {
        guard !didShowCredentialsSyncPausedError else { return }
        Task {
            await MainActor.run {
                let alert = NSAlert.syncCredentialsPaused()
                let response = alert.runModal()
                didShowCredentialsSyncPausedError = true

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

    private var syncDidCompleteSubject = PassthroughSubject<Void, Never>()
    private var syncErrorCancellable: AnyCancellable?
}
