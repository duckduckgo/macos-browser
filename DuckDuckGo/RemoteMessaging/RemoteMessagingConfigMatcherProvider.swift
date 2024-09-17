//
//  RemoteMessagingConfigMatcherProvider.swift
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

import Foundation
import BrowserServicesKit
import Persistence
import Bookmarks
import RemoteMessaging
import NetworkProtection
import Subscription
import Freemium

extension DefaultWaitlistActivationDateStore: VPNActivationDateProviding {}

final class RemoteMessagingConfigMatcherProvider: RemoteMessagingConfigMatcherProviding {

    init(
        bookmarksDatabase: CoreDataDatabase,
        appearancePreferences: AppearancePreferences,
        startupPreferencesPersistor: @escaping @autoclosure () -> StartupPreferencesPersistor = StartupPreferencesUserDefaultsPersistor(),
        duckPlayerPreferencesPersistor: @escaping @autoclosure () -> DuckPlayerPreferencesPersistor = DuckPlayerPreferencesUserDefaultsPersistor(),
        pinnedTabsManager: PinnedTabsManager,
        internalUserDecider: InternalUserDecider,
        statisticsStore: StatisticsStore = LocalStatisticsStore(),
        variantManager: VariantManager = DefaultVariantManager()
    ) {
        self.bookmarksDatabase = bookmarksDatabase
        self.appearancePreferences = appearancePreferences
        self.startupPreferencesPersistor = startupPreferencesPersistor
        self.duckPlayerPreferencesPersistor = duckPlayerPreferencesPersistor
        self.pinnedTabsManager = pinnedTabsManager
        self.internalUserDecider = internalUserDecider
        self.statisticsStore = statisticsStore
        self.variantManager = variantManager
    }

    let bookmarksDatabase: CoreDataDatabase
    let appearancePreferences: AppearancePreferences
    let startupPreferencesPersistor: () -> StartupPreferencesPersistor
    let duckPlayerPreferencesPersistor: () -> DuckPlayerPreferencesPersistor
    let pinnedTabsManager: PinnedTabsManager
    let internalUserDecider: InternalUserDecider
    let statisticsStore: StatisticsStore
    let variantManager: VariantManager

    func refreshConfigMatcher(using store: RemoteMessagingStoring) async -> RemoteMessagingConfigMatcher {

        var bookmarksCount = 0
        var favoritesCount = 0
        let context = bookmarksDatabase.makeContext(concurrencyType: .privateQueueConcurrencyType)
        context.performAndWait {
            bookmarksCount = BookmarkUtils.numberOfBookmarks(in: context)
            favoritesCount = BookmarkUtils.numberOfFavorites(for: appearancePreferences.favoritesDisplayMode, in: context)
        }

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

                surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(
                    statisticsStore: statisticsStore,
                    vpnActivationDateStore: DefaultWaitlistActivationDateStore(source: .netP),
                    subscription: subscription
                )
            } else {
                surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(
                    statisticsStore: statisticsStore,
                    vpnActivationDateStore: DefaultWaitlistActivationDateStore(source: .netP),
                    subscription: nil
                )
            }
        } else {
            surveyActionMapper = DefaultRemoteMessagingSurveyURLBuilder(
                statisticsStore: statisticsStore,
                vpnActivationDateStore: DefaultWaitlistActivationDateStore(source: .netP),
                subscription: nil
            )
        }

        let dismissedMessageIds = store.fetchDismissedRemoteMessageIDs()
        let shownMessageIds = store.fetchShownRemoteMessageIDs()

#if APPSTORE
        let isInstalledMacAppStore = true
#else
        let isInstalledMacAppStore = false
#endif

        let duckPlayerPreferencesPersistor = duckPlayerPreferencesPersistor()

        let deprecatedRemoteMessageStorage = DefaultSurveyRemoteMessagingStorage.surveys()

        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)
        let isCurrentFreemiumDBPUser = !subscriptionManager.accountManager.isUserAuthenticated && freemiumDBPUserStateManager.didActivate

        return RemoteMessagingConfigMatcher(
            appAttributeMatcher: AppAttributeMatcher(statisticsStore: statisticsStore,
                                                     variantManager: variantManager,
                                                     isInternalUser: internalUserDecider.isInternalUser,
                                                     isInstalledMacAppStore: isInstalledMacAppStore),
            userAttributeMatcher: UserAttributeMatcher(statisticsStore: statisticsStore,
                                                       variantManager: variantManager,
                                                       bookmarksCount: bookmarksCount,
                                                       favoritesCount: favoritesCount,
                                                       appTheme: appearancePreferences.currentThemeName.rawValue,
                                                       daysSinceNetPEnabled: daysSinceNetworkProtectionEnabled,
                                                       isPrivacyProEligibleUser: isPrivacyProEligibleUser,
                                                       isPrivacyProSubscriber: isPrivacyProSubscriber,
                                                       privacyProDaysSinceSubscribed: privacyProDaysSinceSubscribed,
                                                       privacyProDaysUntilExpiry: privacyProDaysUntilExpiry,
                                                       privacyProPurchasePlatform: privacyProPurchasePlatform,
                                                       isPrivacyProSubscriptionActive: isPrivacyProSubscriptionActive,
                                                       isPrivacyProSubscriptionExpiring: isPrivacyProSubscriptionExpiring,
                                                       isPrivacyProSubscriptionExpired: isPrivacyProSubscriptionExpired,
                                                       dismissedMessageIds: dismissedMessageIds,
                                                       shownMessageIds: shownMessageIds,
                                                       pinnedTabsCount: pinnedTabsManager.tabCollection.tabs.count,
                                                       hasCustomHomePage: startupPreferencesPersistor().launchToCustomHomePage,
                                                       isDuckPlayerOnboarded: duckPlayerPreferencesPersistor.youtubeOverlayAnyButtonPressed,
                                                       isDuckPlayerEnabled: duckPlayerPreferencesPersistor.duckPlayerModeBool != false,
                                                       isCurrentFreemiumPIRUser: isCurrentFreemiumDBPUser,
                                                       dismissedDeprecatedMacRemoteMessageIds: deprecatedRemoteMessageStorage.dismissedMessageIDs()
                                                      ),
            percentileStore: RemoteMessagingPercentileUserDefaultsStore(keyValueStore: UserDefaults.standard),
            surveyActionMapper: surveyActionMapper,
            dismissedMessageIds: dismissedMessageIds
        )
    }
}
