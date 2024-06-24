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
import Common
import Foundation
import BrowserServicesKit
import Persistence
import PixelKit
import Bookmarks
import RemoteMessaging
import NetworkProtection
import Subscription

final class RemoteMessagingClient {

    init(database: RemoteMessagingDatabase, bookmarksDatabase: CoreDataDatabase, appearancePreferences: AppearancePreferences) {
        self.database = database
        self.bookmarksDatabase = bookmarksDatabase
        self.appearancePreferences = appearancePreferences
    }

    func initializeDatabaseIfNeeded() {
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
        store = RemoteMessagingStore(database: database.db, errorEvents: RemoteMessagingStoreErrorHandling())
        isRemoteMessagingDatabaseLoaded = true
    }

    let database: RemoteMessagingDatabase
    let bookmarksDatabase: CoreDataDatabase
    let appearancePreferences: AppearancePreferences
    private(set) var store: RemoteMessagingStore?
    private var isRemoteMessagingDatabaseLoaded = false
    private var timerCancellable: AnyCancellable?

    private static let endpoint: URL = {
#if DEBUG
        URL(string: "https://www.jsonblob.com/api/1252947611702124544")!
#else
        URL(string: "https://staticcdn.duckduckgo.com/remotemessaging/config/v1/ios-config.json")!
#endif
    }()

    @UserDefaultsWrapper(key: .lastRemoteMessagingRefreshDate, defaultValue: .distantPast)
    static private var lastRemoteMessagingRefreshDate: Date

    struct Constants {
        static let minimumConfigurationRefreshInterval: TimeInterval = 60 * 60 * 4
    }

    static private var shouldRefresh: Bool {
        return Date().timeIntervalSince(Self.lastRemoteMessagingRefreshDate) > Constants.minimumConfigurationRefreshInterval
    }

    func startRefreshingRemoteMessages() {
        timerCancellable = Timer.publish(every: Constants.minimumConfigurationRefreshInterval, on: .main, in: .default)
            .autoconnect()
            .prepend(Date())
            .asVoid()
            .sink { [weak self] in
                self?.refreshRemoteMessages()
            }
    }

    private func refreshRemoteMessages() {
        Task {
            try? await fetchAndProcess()
        }
    }

    /// Convenience function
    private func fetchAndProcess() async throws {

        var bookmarksCount = 0
        var favoritesCount = 0
        let context = bookmarksDatabase.makeContext(concurrencyType: .privateQueueConcurrencyType)
        context.performAndWait {
            let displayedFavoritesFolder = BookmarkUtils.fetchFavoritesFolder(
                withUUID: appearancePreferences.favoritesDisplayMode.displayedFolder.rawValue,
                in: context
            )!

            let bookmarksCountRequest = BookmarkEntity.fetchRequest()
            bookmarksCountRequest.predicate = NSPredicate(
                format: "SUBQUERY(%K, $x, $x CONTAINS %@).@count == 0 AND %K == false AND %K == false AND (%K == NO OR %K == nil)",
                #keyPath(BookmarkEntity.favoriteFolders),
                displayedFavoritesFolder,
                #keyPath(BookmarkEntity.isFolder),
                #keyPath(BookmarkEntity.isPendingDeletion),
                #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
            bookmarksCount = (try? context.count(for: bookmarksCountRequest)) ?? 0

            let favoritesCountRequest = BookmarkEntity.fetchRequest()
            favoritesCountRequest.predicate = NSPredicate(format: "%K CONTAINS %@ AND %K == false AND %K == false AND (%K == NO OR %K == nil)",
                                                          #keyPath(BookmarkEntity.favoriteFolders),
                                                          displayedFavoritesFolder,
                                                          #keyPath(BookmarkEntity.isFolder),
                                                          #keyPath(BookmarkEntity.isPendingDeletion),
                                                          #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
            favoritesCount = (try? context.count(for: favoritesCountRequest)) ?? 0
        }

        try await fetchAndProcess(bookmarksCount: bookmarksCount, favoritesCount: favoritesCount)
    }

    // swiftlint:disable:next function_body_length
    private func fetchAndProcess(bookmarksCount: Int,
                                 favoritesCount: Int,
                                 statisticsStore: StatisticsStore = LocalStatisticsStore(),
                                 variantManager: VariantManager = DefaultVariantManager()) async throws {

        guard let store else {
            return
        }

        let result = await Self.fetchRemoteMessages(remoteMessageRequest: RemoteMessageRequest(endpoint: Self.endpoint))

        switch result {
        case .success(let statusResponse):
            os_log("Successfully fetched remote messages", log: .remoteMessaging, type: .debug)

            let subscriptionManager = await Application.appDelegate.subscriptionManager

            let isPrivacyProSubscriber = subscriptionManager.accountManager.isUserAuthenticated
            let canPurchase = subscriptionManager.canPurchase

            let activationDateStore = DefaultWaitlistActivationDateStore(source: .netP)
            let daysSinceNetworkProtectionEnabled = activationDateStore.daysSinceActivation() ?? -1

            var privacyProDaysSinceSubscribed: Int = -1
            var privacyProDaysUntilExpiry: Int = -1
            var privacyProPurchasePlatform: String?
            var privacyProIsActive: Bool = false
            var privacyProIsExpiring: Bool = false
            var privacyProIsExpired: Bool = false
            let surveyActionMapper: DefaultRemoteMessagingSurveyURLBuilder

            if let accessToken = subscriptionManager.accountManager.accessToken {
                let subscriptionResult = await subscriptionManager.subscriptionService.getSubscription(accessToken: accessToken)

                if case let .success(subscription) = subscriptionResult {
                    privacyProDaysSinceSubscribed = Calendar.current.numberOfDaysBetween(subscription.startedAt, and: Date()) ?? -1
                    privacyProDaysUntilExpiry = Calendar.current.numberOfDaysBetween(Date(), and: subscription.expiresOrRenewsAt) ?? -1
                    privacyProPurchasePlatform = subscription.platform.rawValue

                    switch subscription.status {
                    case .autoRenewable, .gracePeriod:
                        privacyProIsActive = true
                    case .notAutoRenewable:
                        privacyProIsActive = true
                        privacyProIsExpiring = true
                    case .expired, .inactive:
                        privacyProIsExpired = true
                    case .unknown:
                        break // Not supported in RMF
                    }

                    surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(statisticsStore: statisticsStore, subscription: subscription)
                } else {
                    surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(statisticsStore: statisticsStore, subscription: nil)
                }
            } else {
                surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(statisticsStore: statisticsStore, subscription: nil)
            }

            let dismissedMessageIds = store.fetchDismissedRemoteMessageIds()

            let remoteMessagingConfigMatcher = RemoteMessagingConfigMatcher(
                appAttributeMatcher: AppAttributeMatcher(statisticsStore: statisticsStore,
                                                         variantManager: variantManager,
                                                         isInternalUser: await Application.appDelegate.internalUserDecider.isInternalUser),
                userAttributeMatcher: UserAttributeMatcher(statisticsStore: statisticsStore,
                                                           variantManager: variantManager,
                                                           bookmarksCount: bookmarksCount,
                                                           favoritesCount: favoritesCount,
                                                           appTheme: AppearancePreferences.shared.currentThemeName.rawValue,
                                                           isWidgetInstalled: false,
                                                           daysSinceNetPEnabled: daysSinceNetworkProtectionEnabled,
                                                           isPrivacyProEligibleUser: canPurchase,
                                                           isPrivacyProSubscriber: isPrivacyProSubscriber,
                                                           privacyProDaysSinceSubscribed: privacyProDaysSinceSubscribed,
                                                           privacyProDaysUntilExpiry: privacyProDaysUntilExpiry,
                                                           privacyProPurchasePlatform: privacyProPurchasePlatform,
                                                           isPrivacyProSubscriptionActive: privacyProIsActive,
                                                           isPrivacyProSubscriptionExpiring: privacyProIsExpiring,
                                                           isPrivacyProSubscriptionExpired: privacyProIsExpired,
                                                           dismissedMessageIds: dismissedMessageIds),
                percentileStore: RemoteMessagingPercentileUserDefaultsStore(userDefaults: .standard),
                surveyActionMapper: surveyActionMapper,
                dismissedMessageIds: dismissedMessageIds
            )

            let processor = RemoteMessagingConfigProcessor(remoteMessagingConfigMatcher: remoteMessagingConfigMatcher)
            let config = store.fetchRemoteMessagingConfig()

            if let processorResult = processor.process(jsonRemoteMessagingConfig: statusResponse,
                                                       currentConfig: config) {
                store.saveProcessedResult(processorResult)
            }
        case .failure(let error):
            os_log("Failed to fetch remote messages", log: .remoteMessaging, type: .error)
            throw error
        }
    }

    static func fetchRemoteMessages(remoteMessageRequest: RemoteMessageRequest) async -> Result<RemoteMessageResponse.JsonRemoteMessagingConfig, RemoteMessageResponse.StatusError> {
        return await withCheckedContinuation { continuation in
            remoteMessageRequest.getRemoteMessage(completionHandler: { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: .success(response))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            })
        }
    }
}
