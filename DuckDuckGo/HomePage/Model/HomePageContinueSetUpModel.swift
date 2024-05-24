//
//  HomePageContinueSetUpModel.swift
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

import AppKit
import BrowserServicesKit
import Common
import Foundation
import PixelKit
import Subscription

import NetworkProtection
import NetworkProtectionUI

extension HomePage.Models {

    static let newHomePageTabOpen = Notification.Name("newHomePageAppOpen")

    final class ContinueSetUpModel: ObservableObject {
        let itemWidth = FeaturesGridDimensions.itemWidth
        let itemHeight = FeaturesGridDimensions.itemHeight
        let horizontalSpacing = FeaturesGridDimensions.horizontalSpacing
        let verticalSpacing = FeaturesGridDimensions.verticalSpacing
        let itemsPerRow = HomePage.featuresPerRow
        let itemsRowCountWhenCollapsed = HomePage.featureRowCountWhenCollapsed
        let gridWidth = FeaturesGridDimensions.width
        let deleteActionTitle = UserText.newTabSetUpRemoveItemAction
        let privacyConfigurationManager: PrivacyConfigurationManaging
        let surveyRemoteMessaging: SurveyRemoteMessaging
        let permanentSurveyManager: SurveyManager

        var duckPlayerURL: String {
            let duckPlayerSettings = privacyConfigurationManager.privacyConfig.settings(for: .duckPlayer)
            return duckPlayerSettings["tryDuckPlayerLink"] as? String ?? "https://www.youtube.com/watch?v=yKWIA-Pys4c"
        }

        private let defaultBrowserProvider: DefaultBrowserProvider
        private let dockCustomizer: DockCustomization
        private let dataImportProvider: DataImportStatusProviding
        private let tabCollectionViewModel: TabCollectionViewModel
        private let emailManager: EmailManager
        private let duckPlayerPreferences: DuckPlayerPreferencesPersistor
        private let subscriptionManager: SubscriptionManaging

        @UserDefaultsWrapper(key: .homePageShowAllFeatures, defaultValue: false)
        var shouldShowAllFeatures: Bool {
            didSet {
                updateVisibleMatrix()
            }
        }

        @UserDefaultsWrapper(key: .homePageShowMakeDefault, defaultValue: true)
        private var shouldShowMakeDefaultSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowAddToDock, defaultValue: true)
        private var shouldShowAddToDockSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowImport, defaultValue: true)
        private var shouldShowImportSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowDuckPlayer, defaultValue: true)
        private var shouldShowDuckPlayerSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowEmailProtection, defaultValue: true)
        private var shouldShowEmailProtectionSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowPermanentSurvey, defaultValue: true)
        private var shouldShowPermanentSurvey: Bool

        @UserDefaultsWrapper(key: .shouldShowDBPWaitlistInvitedCardUI, defaultValue: false)
        private var shouldShowDBPWaitlistInvitedCardUI: Bool

        @UserDefaultsWrapper(key: .homePageIsFirstSession, defaultValue: true)
        private var isFirstSession: Bool

        var isMoreOrLessButtonNeeded: Bool {
            return featuresMatrix.count > itemsRowCountWhenCollapsed
        }

        var hasContent: Bool {
            return !featuresMatrix.isEmpty
        }

        lazy var listOfFeatures = isFirstSession ? firstRunFeatures : randomisedFeatures

        private var featuresMatrix: [[FeatureType]] = [[]] {
            didSet {
                updateVisibleMatrix()
            }
        }

        @Published var visibleFeaturesMatrix: [[FeatureType]] = [[]]

        init(defaultBrowserProvider: DefaultBrowserProvider,
             dockCustomizer: DockCustomization,
             dataImportProvider: DataImportStatusProviding,
             tabCollectionViewModel: TabCollectionViewModel,
             emailManager: EmailManager = EmailManager(),
             duckPlayerPreferences: DuckPlayerPreferencesPersistor,
             surveyRemoteMessaging: SurveyRemoteMessaging,
             privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager,
             permanentSurveyManager: SurveyManager = PermanentSurveyManager(),
             subscriptionManager: SubscriptionManaging = Application.appDelegate.subscriptionManager) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dockCustomizer = dockCustomizer
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.duckPlayerPreferences = duckPlayerPreferences
            self.surveyRemoteMessaging = surveyRemoteMessaging
            self.privacyConfigurationManager = privacyConfigurationManager
            self.permanentSurveyManager = permanentSurveyManager
            self.subscriptionManager = subscriptionManager

            refreshFeaturesMatrix()

            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }

        @MainActor func performAction(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                performDefaultBrowserAction()
            case .dock:
                performDockAction()
            case .importBookmarksAndPasswords:
                performImportBookmarksAndPasswordsAction()
            case .duckplayer:
                performDuckPlayerAction()
            case .emailProtection:
                performEmailProtectionAction()
            case .permanentSurvey:
                visitSurvey()
            case .surveyRemoteMessage(let message):
                handle(remoteMessage: message)
            case .dataBrokerProtectionWaitlistInvited:
                performDataBrokerProtectionWaitlistInvitedAction()
            }
        }

        private func performDefaultBrowserAction() {
            do {
                PixelKit.fire(GeneralPixel.defaultRequestedFromHomepageSetupView)
                try defaultBrowserProvider.presentDefaultBrowserPrompt()
            } catch {
                defaultBrowserProvider.openSystemPreferences()
            }
        }

        private func performImportBookmarksAndPasswordsAction() {
            dataImportProvider.showImportWindow(completion: { self.refreshFeaturesMatrix() })
        }

        @MainActor
        private func performDuckPlayerAction() {
            if let videoUrl = URL(string: duckPlayerURL) {
                let tab = Tab(content: .url(videoUrl, source: .link), shouldLoadInBackground: true)
                tabCollectionViewModel.append(tab: tab)
            }
        }

        @MainActor
        private func performEmailProtectionAction() {
            let tab = Tab(content: .url(EmailUrls().emailProtectionLink, source: .ui), shouldLoadInBackground: true)
            tabCollectionViewModel.append(tab: tab)
        }

        @MainActor
        private func performDataBrokerProtectionWaitlistInvitedAction() {
        #if DBP
            DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .cardUI)
        #endif
        }

        func performDockAction() {
            PixelKit.fire(GeneralPixel.userAddedToDockFromNewTabPageCard,
                          includeAppVersionParameter: false)
            dockCustomizer.addToDock()
        }

        func removeItem(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                shouldShowMakeDefaultSetting = false
            case .dock:
                shouldShowAddToDockSetting = false
            case .importBookmarksAndPasswords:
                shouldShowImportSetting = false
            case .duckplayer:
                shouldShowDuckPlayerSetting = false
            case .emailProtection:
                shouldShowEmailProtectionSetting = false
            case .permanentSurvey:
                shouldShowPermanentSurvey = false
            case .surveyRemoteMessage(let message):
                surveyRemoteMessaging.dismiss(message: message)
                PixelKit.fire(GeneralPixel.surveyRemoteMessageDismissed(messageID: message.id))
            case .dataBrokerProtectionWaitlistInvited:
                shouldShowDBPWaitlistInvitedCardUI = false
            }
            refreshFeaturesMatrix()
        }

        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []

            if shouldDBPWaitlistCardBeVisible {
                features.append(.dataBrokerProtectionWaitlistInvited)
            }

            for message in surveyRemoteMessaging.presentableRemoteMessages() {
                features.append(.surveyRemoteMessage(message))
                PixelKit.fire(GeneralPixel.surveyRemoteMessageDisplayed(messageID: message.id), frequency: .daily)
            }

            appendFeatureCards(&features)

            featuresMatrix = features.chunked(into: itemsPerRow)
        }

        private func appendFeatureCards(_ features: inout [FeatureType]) {
            for feature in listOfFeatures where shouldAppendFeature(feature: feature) {
                features.append(feature)
            }
        }

        private func shouldAppendFeature(feature: FeatureType) -> Bool {
            switch feature {
            case .defaultBrowser:
                return shouldMakeDefaultCardBeVisible
            case .importBookmarksAndPasswords:
                return shouldImportCardBeVisible
            case .dock:
                return shouldDockCardBeVisible
            case .duckplayer:
                return shouldDuckPlayerCardBeVisible
            case .emailProtection:
                return shouldEmailProtectionCardBeVisible
            case .permanentSurvey:
                return shouldPermanentSurveyBeVisible
            case .surveyRemoteMessage,
                 .dataBrokerProtectionWaitlistInvited:
                return false // These are handled separately
            }
        }

        // Helper Functions
        @MainActor(unsafe)
        @objc private func newTabOpenNotification(_ notification: Notification) {
            if !isFirstSession {
                listOfFeatures = randomisedFeatures
            }
#if DEBUG
            isFirstSession = false
#endif
            if OnboardingViewModel.isOnboardingFinished {
                isFirstSession = false
            }
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            refreshFeaturesMatrix()
        }

        var randomisedFeatures: [FeatureType] {
            var features: [FeatureType]  = [.permanentSurvey, .defaultBrowser]
            var shuffledFeatures = FeatureType.allCases.filter { $0 != .defaultBrowser && $0 != .permanentSurvey }
            shuffledFeatures.shuffle()
            features.append(contentsOf: shuffledFeatures)
            return features
        }

        var firstRunFeatures: [FeatureType] {
            var features = FeatureType.allCases.filter { $0 != .duckplayer }
            features.insert(.duckplayer, at: 0)
            return features
        }

        private func updateVisibleMatrix() {
            guard !featuresMatrix.isEmpty else {
                visibleFeaturesMatrix = [[]]
                return
            }
            visibleFeaturesMatrix = shouldShowAllFeatures ? featuresMatrix : [featuresMatrix[0]]
        }

        private var shouldMakeDefaultCardBeVisible: Bool {
            shouldShowMakeDefaultSetting &&
            !defaultBrowserProvider.isDefault
        }

        private var shouldDockCardBeVisible: Bool {
#if !APPSTORE
            shouldShowAddToDockSetting &&
            !dockCustomizer.isAddedToDock
#else
            return false
#endif
        }

        private var shouldImportCardBeVisible: Bool {
            shouldShowImportSetting &&
            !dataImportProvider.didImport
        }

        private var shouldDuckPlayerCardBeVisible: Bool {
            shouldShowDuckPlayerSetting &&
            duckPlayerPreferences.duckPlayerModeBool == nil &&
            !duckPlayerPreferences.youtubeOverlayAnyButtonPressed
        }

        private var shouldDBPWaitlistCardBeVisible: Bool {
#if DBP
            shouldShowDBPWaitlistInvitedCardUI
#else
            return false
#endif
        }

        private var shouldEmailProtectionCardBeVisible: Bool {
            shouldShowEmailProtectionSetting &&
            !emailManager.isSignedIn
        }

        private var shouldPermanentSurveyBeVisible: Bool {
            return shouldShowPermanentSurvey &&
            permanentSurveyManager.isSurveyAvailable &&
            surveyRemoteMessaging.presentableRemoteMessages().isEmpty // When Privacy Pro survey is visible, ensure we do not show multiple at once
        }

        @MainActor private func visitSurvey() {
            guard let url = permanentSurveyManager.url else { return }

            let tab = Tab(content: .url(url, source: .ui), shouldLoadInBackground: true)
            tabCollectionViewModel.append(tab: tab)
            shouldShowPermanentSurvey = false
        }

        @MainActor private func handle(remoteMessage: SurveyRemoteMessage) {
            guard let actionType = remoteMessage.action.actionType else {
                PixelKit.fire(GeneralPixel.surveyRemoteMessageDismissed(messageID: remoteMessage.id))
                surveyRemoteMessaging.dismiss(message: remoteMessage)
                refreshFeaturesMatrix()
                return
            }

            switch actionType {
            case .openSurveyURL, .openURL:
                Task { @MainActor in
                    var subscription: Subscription?

                    if let token = subscriptionManager.accountManager.accessToken {
                        switch await subscriptionManager.subscriptionService.getSubscription(
                            accessToken: token,
                            cachePolicy: .returnCacheDataElseLoad
                        ) {
                        case .success(let fetchedSubscription):
                            subscription = fetchedSubscription
                        case .failure:
                            break
                        }
                    }

                    if let surveyURL = remoteMessage.presentableSurveyURL(subscription: subscription) {
                        let tab = Tab(content: .url(surveyURL, source: .ui), shouldLoadInBackground: true)
                        tabCollectionViewModel.append(tab: tab)
                        PixelKit.fire(GeneralPixel.surveyRemoteMessageOpened(messageID: remoteMessage.id))

                        // Dismiss the message after the user opens the URL, even if they just close the tab immediately afterwards.
                        surveyRemoteMessaging.dismiss(message: remoteMessage)
                        refreshFeaturesMatrix()
                    }
                }
            }
        }

    }

    // MARK: Feature Type
    enum FeatureType: CaseIterable, Equatable, Hashable {

        // CaseIterable doesn't work with enums that have associated values, so we have to implement it manually.
        // We ignore the `networkProtectionRemoteMessage` case here to avoid it getting accidentally included - it has special handling and will get
        // included elsewhere.
        static var allCases: [HomePage.Models.FeatureType] {
#if APPSTORE
            [.duckplayer, .emailProtection, .defaultBrowser, .importBookmarksAndPasswords, .permanentSurvey]
#else
            [.duckplayer, .emailProtection, .defaultBrowser, .dock, .importBookmarksAndPasswords, .permanentSurvey]
#endif
        }

        case duckplayer
        case emailProtection
        case defaultBrowser
        case dock
        case importBookmarksAndPasswords
        case permanentSurvey
        case surveyRemoteMessage(SurveyRemoteMessage)
        case dataBrokerProtectionWaitlistInvited

        var title: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserCardTitle
            case .dock:
                return UserText.newTabSetUpDockCardTitle
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportCardTitle
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerCardTitle
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionCardTitle
            case .permanentSurvey:
                return PermanentSurveyManager.title
            case .surveyRemoteMessage(let message):
                return message.cardTitle
            case .dataBrokerProtectionWaitlistInvited:
                return "Personal Information Removal"
            }
        }

        var summary: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserSummary
            case .dock:
                return UserText.newTabSetUpDockSummary
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportSummary
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerSummary
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionSummary
            case .permanentSurvey:
                return PermanentSurveyManager.body
            case .surveyRemoteMessage(let message):
                return message.cardDescription
            case .dataBrokerProtectionWaitlistInvited:
                return "You're invited to try Personal Information Removal beta!"
            }
        }

        var action: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserAction
            case .dock:
                return UserText.newTabSetUpDockAction
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportAction
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerAction
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionAction
            case .permanentSurvey:
                return PermanentSurveyManager.actionTitle
            case .surveyRemoteMessage(let message):
                return message.action.actionTitle
            case .dataBrokerProtectionWaitlistInvited:
                return "Get Started"
            }
        }

        var confirmation: String? {
            switch self {
            case .dock:
                return UserText.newTabSetUpDockConfirmation
            default:
                return nil
            }
        }

        var icon: NSImage {
            let iconSize = NSSize(width: 64, height: 48)

            switch self {
            case .defaultBrowser:
                return .defaultApp128.resized(to: iconSize)!
            case .dock:
                return .dock128.resized(to: iconSize)!
            case .importBookmarksAndPasswords:
                return .import128.resized(to: iconSize)!
            case .duckplayer:
                return .cleanTube128.resized(to: iconSize)!
            case .emailProtection:
                return .inbox128.resized(to: iconSize)!
            case .permanentSurvey:
                return .survey128.resized(to: iconSize)!
            case .surveyRemoteMessage:
                return .privacyProSurvey.resized(to: iconSize)!
            case .dataBrokerProtectionWaitlistInvited:
                return .dbpInformationRemover.resized(to: iconSize)!
            }
        }
    }

    enum FeaturesGridDimensions {
        static let itemWidth: CGFloat = 240
        static let itemHeight: CGFloat = 160
        static let verticalSpacing: CGFloat = 16
        static let horizontalSpacing: CGFloat = 24

        static let width: CGFloat = (itemWidth + horizontalSpacing) * CGFloat(HomePage.featuresPerRow) - horizontalSpacing

        static func height(for rowCount: Int) -> CGFloat {
            (itemHeight + verticalSpacing) * CGFloat(rowCount) - verticalSpacing
        }
    }
}

// MARK: - Remote Messaging

extension AppVersion {
    public var majorAndMinorOSVersion: String {
        let components = osVersion.split(separator: ".")
        guard components.count >= 2 else {
            return majorVersionNumber
        }
        return "\(components[0]).\(components[1])"
    }
}
