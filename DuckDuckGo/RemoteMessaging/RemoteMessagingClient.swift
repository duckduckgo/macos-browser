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

final class RemoteMessagingConfigMatcherProvider: RemoteMessagingConfigMatcherProviding {

    init(
        bookmarksDatabase: CoreDataDatabase,
        appearancePreferences: AppearancePreferences,
        internalUserDecider: InternalUserDecider
    ) {
        self.bookmarksDatabase = bookmarksDatabase
        self.appearancePreferences = appearancePreferences
        self.internalUserDecider = internalUserDecider
    }

    let bookmarksDatabase: CoreDataDatabase
    let appearancePreferences: AppearancePreferences
    let internalUserDecider: InternalUserDecider

    // swiftlint:disable:next function_body_length
    func refreshConfigMatcher(with store: RemoteMessagingStoring) async -> RemoteMessagingConfigMatcher {

        var bookmarksCount = 0
        var favoritesCount = 0
        let context = bookmarksDatabase.makeContext(concurrencyType: .privateQueueConcurrencyType)
        context.performAndWait {
            bookmarksCount = BookmarkUtils.numberOfBookmarks(in: context)
            favoritesCount = BookmarkUtils.numberOfFavorites(for: appearancePreferences.favoritesDisplayMode, in: context)
        }

        let statisticsStore = LocalStatisticsStore()
        let variantManager = DefaultVariantManager()
        let subscriptionManager = await Application.appDelegate.subscriptionManager

        let isPrivacyProSubscriber = subscriptionManager.accountManager.isUserAuthenticated
        let isPrivacyProEligibleUser = subscriptionManager.canPurchase

        let activationDateStore = DefaultWaitlistActivationDateStore(source: .netP)
        let daysSinceNetworkProtectionEnabled = activationDateStore.daysSinceActivation() ?? -1

        var privacyProDaysSinceSubscribed = -1
        var privacyProDaysUntilExpiry = -1
        var isPrivacyProSubscriptionActive = false
        var isPrivacyProSubscriptionExpiring = false
        var isPrivacyProSubscriptionExpired = false
        var privacyProPurchasePlatform: String?
        let surveyActionMapper: RemoteMessagingSurveyActionMapping

        if let accessToken = subscriptionManager.accountManager.accessToken {
            let subscriptionResult = await subscriptionManager.subscriptionEndpointService.getSubscription(accessToken: accessToken)

            if case let .success(subscription) = subscriptionResult {
                privacyProDaysSinceSubscribed = Calendar.current.numberOfDaysBetween(subscription.startedAt, and: Date()) ?? -1
                privacyProDaysUntilExpiry = Calendar.current.numberOfDaysBetween(Date(), and: subscription.expiresOrRenewsAt) ?? -1
                privacyProPurchasePlatform = subscription.platform.rawValue

                switch subscription.status {
                case .autoRenewable, .gracePeriod:
                    isPrivacyProSubscriptionActive = true
                case .notAutoRenewable:
                    isPrivacyProSubscriptionActive = true
                    isPrivacyProSubscriptionExpiring = true
                case .expired, .inactive:
                    isPrivacyProSubscriptionExpired = true
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

        return RemoteMessagingConfigMatcher(
            appAttributeMatcher: AppAttributeMatcher(statisticsStore: statisticsStore,
                                                     variantManager: variantManager,
                                                     isInternalUser: internalUserDecider.isInternalUser),
            userAttributeMatcher: UserAttributeMatcher(statisticsStore: statisticsStore,
                                                       variantManager: variantManager,
                                                       bookmarksCount: bookmarksCount,
                                                       favoritesCount: favoritesCount,
                                                       appTheme: appearancePreferences.currentThemeName.rawValue,
                                                       isWidgetInstalled: false,
                                                       daysSinceNetPEnabled: daysSinceNetworkProtectionEnabled,
                                                       isPrivacyProEligibleUser: isPrivacyProEligibleUser,
                                                       isPrivacyProSubscriber: isPrivacyProSubscriber,
                                                       privacyProDaysSinceSubscribed: privacyProDaysSinceSubscribed,
                                                       privacyProDaysUntilExpiry: privacyProDaysUntilExpiry,
                                                       privacyProPurchasePlatform: privacyProPurchasePlatform,
                                                       isPrivacyProSubscriptionActive: isPrivacyProSubscriptionActive,
                                                       isPrivacyProSubscriptionExpiring: isPrivacyProSubscriptionExpiring,
                                                       isPrivacyProSubscriptionExpired: isPrivacyProSubscriptionExpired,
                                                       dismissedMessageIds: dismissedMessageIds),
            percentileStore: RemoteMessagingPercentileUserDefaultsStore(userDefaults: .standard),
            surveyActionMapper: surveyActionMapper,
            dismissedMessageIds: dismissedMessageIds
        )
    }
}

final class RemoteMessagingClient: RemoteMessagingClientBase {

    struct Constants {
        static let minimumConfigurationRefreshInterval: TimeInterval = 60 * 60 * 4
    }

    init(
        database: RemoteMessagingDatabase,
        bookmarksDatabase: CoreDataDatabase,
        appearancePreferences: AppearancePreferences,
        internalUserDecider: InternalUserDecider
    ) {
        self.database = database
        self.appearancePreferences = appearancePreferences
        self.internalUserDecider = internalUserDecider

        let provider = RemoteMessagingConfigMatcherProvider(
            bookmarksDatabase: bookmarksDatabase,
            appearancePreferences: appearancePreferences,
            internalUserDecider: internalUserDecider
        )
        super.init(endpoint: Self.endpoint, configMatcherProvider: provider)

        subscribeToInternalUserFlagChangesIfNeeded()
    }

    private func subscribeToInternalUserFlagChangesIfNeeded() {
        guard !internalUserDecider.isInternalUser else {
            return
        }

        internalUserCancellable = internalUserDecider.isInternalUserPublisher
            .filter { $0 }
            .prefix(1)
            .sink { [weak self] isInternalUser in
                if isInternalUser {
                    self?.initializeDatabaseIfNeeded()
                    self?.startRefreshingRemoteMessages()
                }
            }
    }

    func initializeDatabaseIfNeeded() {
        guard internalUserDecider.isInternalUser else {
            return
        }
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

    func startRefreshingRemoteMessages() {
        guard internalUserDecider.isInternalUser else {
            return
        }
        timerCancellable = Timer.publish(every: Constants.minimumConfigurationRefreshInterval, on: .main, in: .default)
            .autoconnect()
            .prepend(Date())
            .asVoid()
            .sink { [weak self] in
                self?.refreshRemoteMessages()
            }
    }

    private let database: RemoteMessagingDatabase
    private let appearancePreferences: AppearancePreferences
    private let internalUserDecider: InternalUserDecider
    private(set) var store: RemoteMessagingStore?
    private var isRemoteMessagingDatabaseLoaded = false
    private var timerCancellable: AnyCancellable?
    private var internalUserCancellable: AnyCancellable?

    private static let endpoint: URL = {
#if DEBUG
        URL(string: "https://www.jsonblob.com/api/1252947611702124544")!
#else
        URL(string: "https://staticcdn.duckduckgo.com/remotemessaging/config/v1/ios-config.json")!
#endif
    }()

    @UserDefaultsWrapper(key: .lastRemoteMessagingRefreshDate, defaultValue: .distantPast)
    static private var lastRemoteMessagingRefreshDate: Date

    private func refreshRemoteMessages() {
        guard let store else {
            return
        }

        Task {
            try? await fetchAndProcess(remoteMessagingStore: store)
        }
    }
}
