//
//  SyncErrorHandler.swift
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

import Common
import DDGSync
import Foundation
import PixelKit
import Persistence
import Combine

public class SyncErrorHandler: EventMapping<SyncError>, ObservableObject {

    @UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false)
    private (set) var isSyncBookmarksPaused: Bool {
        didSet {
            isSyncPausedChangedPublisher.send()
        }
    }

    @UserDefaultsWrapper(key: .syncCredentialsPaused, defaultValue: false)
    private (set) var isSyncCredentialsPaused: Bool {
        didSet {
            isSyncPausedChangedPublisher.send()
        }
    }

    @UserDefaultsWrapper(key: .synclsPaused, defaultValue: false)
    private (set) var isSyncPaused: Bool {
        didSet {
            isSyncPausedChangedPublisher.send()
        }
    }

    @UserDefaultsWrapper(key: .syncBookmarksPausedErrorDisplayed, defaultValue: false)
    private var didShowBookmarksSyncPausedError: Bool

    @UserDefaultsWrapper(key: .syncCredentialsPausedErrorDisplayed, defaultValue: false)
    private var didShowCredentialsSyncPausedError: Bool

    @UserDefaultsWrapper(key: .syncInvalidLoginPausedErrorDisplayed, defaultValue: false)
    private var didShowInvalidLoginSyncPausedError: Bool

    @UserDefaultsWrapper(key: .syncLastErrorNotificationTime, defaultValue: nil)
    private var lastErrorNotificationTime: Date?

    @UserDefaultsWrapper(key: .syncLastSuccesfullTime, defaultValue: nil)
    private var lastSyncSuccessTime: Date?

    @UserDefaultsWrapper(key: .syncLastNonActionableErrorCount, defaultValue: 0)
    private var nonActionableErrorCount: Int

    var isSyncPausedChangedPublisher = PassthroughSubject<Void, Never>()

    private var currentSyncAllPausedError: AsyncErrorType?

    let alertPresenter: AlertPresenter

    public init(alertPresenter: AlertPresenter = StandardAlertPresenter()) {
        self.alertPresenter = alertPresenter
        super.init { event, _, _, _ in
            PixelKit.fire(DebugEvent(GeneralPixel.syncSentUnauthenticatedRequest, error: event))
        }
    }

    override init(mapping: @escaping EventMapping<SyncError>.Mapping) {
        fatalError("Use init()")
    }

    var addErrorPublisher: AnyPublisher<Bool, Never> {
        addErrorSubject.eraseToAnyPublisher()
    }

    private let addErrorSubject: PassthroughSubject<Bool, Never> = .init()
    public let objectWillChange = ObservableObjectPublisher()

    private func resetBookmarksErrors() {
        isSyncBookmarksPaused = false
        didShowBookmarksSyncPausedError = false
        resetGeneralErrors()
    }

    private func resetCredentialsErrors() {
        isSyncCredentialsPaused = false
        didShowCredentialsSyncPausedError = false
        resetGeneralErrors()
    }

    private func resetGeneralErrors() {
        isSyncPaused = false
        didShowInvalidLoginSyncPausedError = false
        lastErrorNotificationTime = nil
        currentSyncAllPausedError = nil
        nonActionableErrorCount = 0
    }

    private func shouldShowAlertForNonActionableError() -> Bool {
        nonActionableErrorCount += 1
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var lastErrorNotificationWasMoreThan24hAgo: Bool
        if let lastErrorNotificationTime {
            lastErrorNotificationWasMoreThan24hAgo = lastErrorNotificationTime < oneDayAgo
        } else {
            lastErrorNotificationWasMoreThan24hAgo = true
        }
        let areThere10ConsecutiveError = nonActionableErrorCount >= 10
        if nonActionableErrorCount >= 10 {
            nonActionableErrorCount = 0
        }
        let twelveHoursAgo = Calendar.current.date(byAdding: .hour, value: -12, to: Date())!
        let noSuccessfulSyncInLast12h = nonActionableErrorCount > 1 && lastSyncSuccessTime ?? Date() <= twelveHoursAgo

        return lastErrorNotificationWasMoreThan24hAgo &&
        (areThere10ConsecutiveError || noSuccessfulSyncInLast12h)
    }

    private var syncPausedTitle: String? {
        guard let error = currentSyncAllPausedError else { return nil }
        switch error {
        case .invalidLoginCredentials:
            return UserText.syncPausedTitle
        case .tooManyRequests, .badRequest:
            return UserText.syncErrorTitle
        default:
            assertionFailure("Sync Paused error should be one of those listes")
            return nil
        }
    }

    private var syncPausedMessage: String? {
        guard let error = currentSyncAllPausedError else { return nil }
        switch error {
        case .invalidLoginCredentials:
            return UserText.invalidLoginCredentialErrorDescription
        case .tooManyRequests:
            return UserText.tooManyRequestsErrorDescription
        case .badRequest:
            return UserText.badRequestErrorDescription
        default:
            assertionFailure("Sync Paused error should be one of those listes")
            return nil
        }
    }
}

extension SyncErrorHandler: SyncAdapterErrorHandler {
    func syncCredentialsSucceded() {
        lastSyncSuccessTime = Date()
        resetCredentialsErrors()
    }

    func syncBookmarksSucceded() {
        lastSyncSuccessTime = Date()
        resetBookmarksErrors()
    }

    func handleBookmarkError(_ error: Error) {
        handleError(error, modelType: .bookmarks)
    }

    func handleCredentialError(_ error: Error) {
        handleError(error, modelType: .credentials)
    }

    private func handleError(_ error: Error, modelType: ModelType) {
        switch error {
        case let syncError as SyncError:
            handleSyncError(syncError, modelType: modelType)
        default:
            let nsError = error as NSError
            if nsError.domain != NSURLErrorDomain {
                let processedErrors = CoreDataErrorsParser.parse(error: error as NSError)
                let params = processedErrors.errorPixelParameters
                PixelKit.fire(DebugEvent(GeneralPixel.syncBookmarksFailed, error: error), withAdditionalParameters: params)
            }
        }
    }

    private func handleSyncError(_ syncError: SyncError, modelType: ModelType) {
        switch modelType {
        case .bookmarks:
            PixelKit.fire(DebugEvent(GeneralPixel.syncBookmarksFailed, error: syncError))
        case .credentials:
            PixelKit.fire(DebugEvent(GeneralPixel.syncCredentialsFailed, error: syncError))
        }
        switch syncError {
        case .unexpectedStatusCode(409):
            switch modelType {
            case .bookmarks:
                syncIsPaused(errorType: .bookmarksCountLimitExceeded)
            case .credentials:
                syncIsPaused(errorType: .credentialsCountLimitExceeded)
            }
        case .unexpectedStatusCode(413):
            switch modelType {
            case .bookmarks:
                syncIsPaused(errorType: .bookmarksRequestSizeLimitExceeded)
            case .credentials:
                syncIsPaused(errorType: .credentialsRequestSizeLimitExceeded)
            }
        case .unexpectedStatusCode(401):
            syncIsPaused(errorType: .invalidLoginCredentials)
        case .unexpectedStatusCode(400):
            syncIsPaused(errorType: .badRequest)
        case .unexpectedStatusCode(418), .unexpectedStatusCode(429):
            syncIsPaused(errorType: .tooManyRequests)
        default:
            break
        }
    }

    private func syncIsPaused(errorType: AsyncErrorType) {
        showSyncPausedAlertIfNeeded(for: errorType)
        switch errorType {
        case .bookmarksCountLimitExceeded:
            self.isSyncBookmarksPaused = true
            PixelKit.fire(GeneralPixel.syncBookmarksCountLimitExceededDaily, frequency: .daily)
        case .credentialsCountLimitExceeded:
            self.isSyncCredentialsPaused = true
            PixelKit.fire(GeneralPixel.syncCredentialsCountLimitExceededDaily, frequency: .daily)
        case .bookmarksRequestSizeLimitExceeded:
            self.isSyncBookmarksPaused = true
            PixelKit.fire(GeneralPixel.syncBookmarksRequestSizeLimitExceededDaily, frequency: .daily)
        case .credentialsRequestSizeLimitExceeded:
            self.isSyncCredentialsPaused = true
            PixelKit.fire(GeneralPixel.syncCredentialsRequestSizeLimitExceededDaily, frequency: .daily)
        case .invalidLoginCredentials:
            currentSyncAllPausedError = errorType
            self.isSyncPaused = true
        case .tooManyRequests, .badRequest:
            currentSyncAllPausedError = errorType
            self.isSyncPaused = true
        }
    }

    private func showSyncPausedAlertIfNeeded(for errorType: AsyncErrorType) {
        Task {
            await MainActor.run {
                var alert: NSAlert
                switch errorType {
                case .bookmarksCountLimitExceeded, .bookmarksRequestSizeLimitExceeded:
                    guard !didShowBookmarksSyncPausedError else { return }
                    alert = NSAlert.syncPaused(title: UserText.syncBookmarkPausedAlertTitle, informative: UserText.syncBookmarkPausedAlertDescription)
                    didShowBookmarksSyncPausedError = true
                case .credentialsCountLimitExceeded, .credentialsRequestSizeLimitExceeded:
                    guard !didShowCredentialsSyncPausedError else { return }
                    alert = NSAlert.syncPaused(title: UserText.syncCredentialsPausedAlertTitle, informative: UserText.syncCredentialsPausedAlertDescription)
                    didShowCredentialsSyncPausedError = true
                case .invalidLoginCredentials:
                    guard !didShowInvalidLoginSyncPausedError else { return }
                    alert = NSAlert.syncPaused(title: UserText.syncPausedAlertTitle, informative: UserText.syncInvalidLoginAlertDescription)
                    didShowInvalidLoginSyncPausedError = true
                case .tooManyRequests:
                    guard shouldShowAlertForNonActionableError() == true else { return }
                    alert = NSAlert.syncPaused(title: UserText.syncErrorAlertTitle, informative: UserText.syncTooManyRequestsAlertDescription)
                    lastErrorNotificationTime = Date()
                case .badRequest:
                    guard shouldShowAlertForNonActionableError() == true else { return }
                    alert = NSAlert.syncPaused(title: UserText.syncErrorAlertTitle, informative: UserText.syncBadRequestAlertDescription)
                    lastErrorNotificationTime = Date()
                }
                alertPresenter.showAlert(alert)
            }
        }
    }

    private enum AsyncErrorType {
        case bookmarksCountLimitExceeded
        case credentialsCountLimitExceeded
        case bookmarksRequestSizeLimitExceeded
        case credentialsRequestSizeLimitExceeded
        case invalidLoginCredentials
        case tooManyRequests
        case badRequest
    }

    private enum ModelType {
        case bookmarks
        case credentials
    }

    @MainActor
    private func manageBookmarks() {
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }
        mainVC.showManageBookmarks(self)
    }

    @MainActor
    private func manageLogins() {
        guard let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController else { return }
        let navigationViewController = parentWindowController.mainViewController.navigationBarViewController
        navigationViewController.showPasswordManagerPopover(selectedCategory: .allItems)
    }

}

extension SyncErrorHandler: SyncPreferencesErrorHandler {
    var syncPausedMetadata: SyncPausedErrorMetadata? {
        guard let syncPausedMessage else { return nil }
        guard let syncPausedTitle else { return nil }
        return SyncPausedErrorMetadata(syncPausedTitle: syncPausedTitle,
                                       syncPausedMessage: syncPausedMessage,
                                       syncPausedButtonTitle: "",
                                       syncPausedAction: nil)
    }

    @MainActor
    var syncBookmarksPausedMetadata: SyncPausedErrorMetadata {
        return SyncPausedErrorMetadata(syncPausedTitle: UserText.syncLimitExceededTitle,
                                       syncPausedMessage: UserText.bookmarksLimitExceededDescription,
                                       syncPausedButtonTitle: UserText.bookmarksLimitExceededAction,
                                       syncPausedAction: manageBookmarks)
    }

    @MainActor
    var syncCredentialsPausedMetadata: SyncPausedErrorMetadata {
        return SyncPausedErrorMetadata(syncPausedTitle: UserText.syncLimitExceededTitle,
                                       syncPausedMessage: UserText.credentialsLimitExceededDescription,
                                       syncPausedButtonTitle: UserText.credentialsLimitExceededAction,
                                       syncPausedAction: manageLogins)
    }

    var syncPausedChangedPublisher: AnyPublisher<Void, Never> {
        isSyncPausedChangedPublisher.eraseToAnyPublisher()
    }

    func syncDidTurnOff() {
        resetBookmarksErrors()
        resetCredentialsErrors()
    }
}

protocol SyncAdapterErrorHandler {
    func handleBookmarkError(_ error: Error)
    func handleCredentialError(_ error: Error)
    func syncBookmarksSucceded()
    func syncCredentialsSucceded()
}

public protocol AlertPresenter {
    func showAlert(_ alert: NSAlert)
}

public struct StandardAlertPresenter: AlertPresenter {
    public init () {}
    @MainActor
    public func showAlert(_ alert: NSAlert) {
        let response = alert.runModal()

        switch response {
        case .alertSecondButtonReturn:
            alert.window.sheetParent?.endSheet(alert.window)
            WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .sync)
        default:
            break
        }
    }
}
