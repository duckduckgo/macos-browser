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
        let homePageRemoteMessaging: HomePageRemoteMessaging

        var isDay0SurveyEnabled: Bool {
            let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
            if let day0SurveyString =  newTabContinueSetUpSettings["surveyCardDay0"] as? String {
                if day0SurveyString == "enabled" {
                    return true
                }
            }
            return false
        }
        var isDay14SurveyEnabled: Bool {
            let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
            if let day14SurveyString =  newTabContinueSetUpSettings["surveyCardDay14"] as? String {
                if day14SurveyString == "enabled" {
                    return true
                }
            }
            return false
        }
        var duckPlayerURL: String {
            let duckPlayerSettings = privacyConfigurationManager.privacyConfig.settings(for: .duckPlayer)
            return duckPlayerSettings["tryDuckPlayerLink"] as? String ?? "https://www.youtube.com/watch?v=yKWIA-Pys4c"
        }
        var day0SurveyURL: String = "https://selfserve.decipherinc.com/survey/selfserve/32ab/240300?list=1"
        var day14SurveyURL: String = "https://selfserve.decipherinc.com/survey/selfserve/32ab/240300?list=2"

        private let defaultBrowserProvider: DefaultBrowserProvider
        private let dockCustomizer: DockCustomization
        private let dataImportProvider: DataImportStatusProviding
        private let tabCollectionViewModel: TabCollectionViewModel
        private let emailManager: EmailManager
        private let duckPlayerPreferences: DuckPlayerPreferencesPersistor
        private let randomNumberGenerator: RandomNumberGenerating

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

        @UserDefaultsWrapper(key: .homePageShowSurveyDay0, defaultValue: true)
        private var shouldShowSurveyDay0: Bool

        @UserDefaultsWrapper(key: .homePageUserInteractedWithSurveyDay0, defaultValue: false)
        private var userInteractedWithSurveyDay0: Bool

        @UserDefaultsWrapper(key: .shouldShowDBPWaitlistInvitedCardUI, defaultValue: false)
        private var shouldShowDBPWaitlistInvitedCardUI: Bool

        @UserDefaultsWrapper(key: .homePageShowSurveyDay14, defaultValue: true)
        private var shouldShowSurveyDay14: Bool

        @UserDefaultsWrapper(key: .homePageIsFirstSession, defaultValue: true)
        private var isFirstSession: Bool

        @UserDefaultsWrapper(key: .homePageShowSurveyDay0in10Percent, defaultValue: nil)
        private var isPartOfSurveyDay0On10Percent: Bool?

        @UserDefaultsWrapper(key: .homePageShowSurveyDay14in10Percent, defaultValue: nil)
        private var isPartOfSurveyDay14On10Percent: Bool?

        @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        private var firstLaunchDate: Date

        var isMoreOrLessButtonNeeded: Bool {
            return featuresMatrix.count > itemsRowCountWhenCollapsed
        }

        var hasContent: Bool {
            return !featuresMatrix.isEmpty
        }

        lazy var statisticsStore: StatisticsStore = LocalStatisticsStore()

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
             homePageRemoteMessaging: HomePageRemoteMessaging,
             privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager,
             randomNumberGenerator: RandomNumberGenerating = RandomNumberGenerator()) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dockCustomizer = dockCustomizer
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.duckPlayerPreferences = duckPlayerPreferences
            self.homePageRemoteMessaging = homePageRemoteMessaging
            self.privacyConfigurationManager = privacyConfigurationManager
            self.randomNumberGenerator = randomNumberGenerator

            refreshFeaturesMatrix()

            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }

        // swiftlint:disable:next cyclomatic_complexity
        @MainActor func performAction(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                do {
                    PixelKit.fire(GeneralPixel.defaultRequestedFromHomepageSetupView)
                    try defaultBrowserProvider.presentDefaultBrowserPrompt()
                } catch {
                    defaultBrowserProvider.openSystemPreferences()
                }
            case .dock:
                dockCustomizer.addToDock()
                removeItem(for: .dock)
            case .importBookmarksAndPasswords:
                dataImportProvider.showImportWindow(completion: {self.refreshFeaturesMatrix()})
            case .duckplayer:
                if let videoUrl = URL(string: duckPlayerURL) {
                    let tab = Tab(content: .url(videoUrl, source: .link), shouldLoadInBackground: true)
                    tabCollectionViewModel.append(tab: tab)
                }
            case .emailProtection:
                let tab = Tab(content: .url(EmailUrls().emailProtectionLink, source: .ui), shouldLoadInBackground: true)
                tabCollectionViewModel.append(tab: tab)
            case .surveyDay0:
                visitSurvey(day: .day0)
            case .surveyDay14:
                visitSurvey(day: .day14)
            case .networkProtectionRemoteMessage(let message):
                handle(remoteMessage: message)
            case .dataBrokerProtectionRemoteMessage(let message):
                handle(remoteMessage: message)
            case .dataBrokerProtectionWaitlistInvited:
#if DBP
                DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .cardUI)
#endif
            }
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
            case .surveyDay0:
                shouldShowSurveyDay0 = false
            case .surveyDay14:
                shouldShowSurveyDay14 = false
            case .networkProtectionRemoteMessage(let message):
                homePageRemoteMessaging.networkProtectionRemoteMessaging.dismiss(message: message)
                PixelKit.fire(GeneralPixel.networkProtectionRemoteMessageDismissed(messageID: message.id))
            case .dataBrokerProtectionRemoteMessage(let message):
#if DBP
                homePageRemoteMessaging.dataBrokerProtectionRemoteMessaging.dismiss(message: message)
                PixelKit.fire(GeneralPixel.dataBrokerProtectionRemoteMessageDismissed(messageID: message.id))
#endif
            case .dataBrokerProtectionWaitlistInvited:
                shouldShowDBPWaitlistInvitedCardUI = false
            }
            refreshFeaturesMatrix()
        }

        // swiftlint:disable:next cyclomatic_complexity function_body_length
        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []
#if DBP
            if shouldDBPWaitlistCardBeVisible {
                features.append(.dataBrokerProtectionWaitlistInvited)
            }

            for message in homePageRemoteMessaging.dataBrokerProtectionRemoteMessaging.presentableRemoteMessages() {
                features.append(.dataBrokerProtectionRemoteMessage(message))
                PixelKit.fire(GeneralPixel.dataBrokerProtectionRemoteMessageDisplayed(messageID: message.id), frequency: .daily)
            }
#endif

            for message in homePageRemoteMessaging.networkProtectionRemoteMessaging.presentableRemoteMessages() {
                PixelKit.fire(GeneralPixel.networkProtectionRemoteMessageDisplayed(messageID: message.id), frequency: .daily)
            }

            for feature in listOfFeatures {
                switch feature {
                case .defaultBrowser:
                    if shouldMakeDefaultCardBeVisible {
                        features.append(feature)
                    }
                case .dock:
                    if shouldDockCardBeVisible {
                        features.append(feature)
                    }
                case .importBookmarksAndPasswords:
                    if shouldImportCardBeVisible {
                        features.append(feature)
                    }
                case .duckplayer:
                    if shouldDuckPlayerCardBeVisible {
                        features.append(feature)
                    }
                case .emailProtection:
                    if shouldEmailProtectionCardBeVisible {
                        features.append(feature)
                    }
                case .surveyDay0:
                    if shouldSurveyDay0BeVisible {
                        features.append(feature)
                        userInteractedWithSurveyDay0 = true
                    }
                case .surveyDay14:
                    if shouldSurveyDay14BeVisible {
                        features.append(feature)
                    }
                case .networkProtectionRemoteMessage,
                        .dataBrokerProtectionRemoteMessage,
                        .dataBrokerProtectionWaitlistInvited:
                    break // Do nothing, these messages get appended first
                }
            }
            featuresMatrix = features.chunked(into: itemsPerRow)
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
            var features = FeatureType.allCases
            features.shuffle()
            for (index, feature) in features.enumerated() where feature == .defaultBrowser {
                features.remove(at: index)
                features.insert(feature, at: 0)
            }
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
            shouldShowAddToDockSetting &&
            !dockCustomizer.isAddedToDock
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

        private var shouldSurveyDay0BeVisible: Bool {
            let oneDayAgo = Calendar.current.date(byAdding: .weekday, value: -1, to: Date())!
            return isDay0SurveyEnabled &&
            shouldShowSurveyDay0 &&
            firstLaunchDate >= oneDayAgo &&
            Bundle.main.preferredLocalizations.first == "en" &&
            isPartOfSurveyDay0On10Percent ?? calculateIfIn10percent(day: .day0)
        }

        private var shouldSurveyDay14BeVisible: Bool {
            let fourteenDaysAgo = Calendar.current.date(byAdding: .weekday, value: -14, to: Date())!
            let fifteenDaysAgo = Calendar.current.date(byAdding: .weekday, value: -15, to: Date())!
            return isDay14SurveyEnabled &&
            shouldShowSurveyDay0 &&
            shouldShowSurveyDay14 &&
            !userInteractedWithSurveyDay0 &&
            firstLaunchDate >= fifteenDaysAgo &&
            firstLaunchDate <= fourteenDaysAgo &&
            Bundle.main.preferredLocalizations.first == "en" &&
            isPartOfSurveyDay14On10Percent ?? calculateIfIn10percent(day: .day14)
        }

        private func calculateIfIn10percent(day: SurveyDay) -> Bool {
            let randomNumber0To99 = randomNumberGenerator.random(in: 0..<100)
            let isInSurvey10Percent = randomNumber0To99 < 10
            switch day {
            case .day0:
                isPartOfSurveyDay0On10Percent = isInSurvey10Percent
            case .day14:
                isPartOfSurveyDay14On10Percent = isInSurvey10Percent
            }
            return isInSurvey10Percent
        }

        private enum SurveyDay {
            case day0
            case day14
        }

        @MainActor private func visitSurvey(day: SurveyDay) {
            var surveyURLString: String
            switch day {
            case .day0:
                surveyURLString = day0SurveyURL
            case .day14:
                surveyURLString = day14SurveyURL
            }

            if let url = URL(string: surveyURLString) {
                let tab = Tab(content: .url(url, source: .ui), shouldLoadInBackground: true)
                tabCollectionViewModel.append(tab: tab)
                switch day {
                case .day0:
                    shouldShowSurveyDay0 = false
                case .day14:
                    shouldShowSurveyDay14 = false
                }
            }
        }

        @MainActor private func handle(remoteMessage: NetworkProtectionRemoteMessage) {
            guard let actionType = remoteMessage.action.actionType else {
                PixelKit.fire(GeneralPixel.networkProtectionRemoteMessageDismissed(messageID: remoteMessage.id))
                homePageRemoteMessaging.networkProtectionRemoteMessaging.dismiss(message: remoteMessage)
                refreshFeaturesMatrix()
                return
            }

            switch actionType {
            case .openNetworkProtection:
                NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: nil)
            case .openSurveyURL, .openURL:
                if let surveyURL = remoteMessage.presentableSurveyURL() {
                    let tab = Tab(content: .url(surveyURL, source: .ui), shouldLoadInBackground: true)
                    tabCollectionViewModel.append(tab: tab)
                    PixelKit.fire(GeneralPixel.networkProtectionRemoteMessageOpened(messageID: remoteMessage.id))

                    // Dismiss the message after the user opens the URL, even if they just close the tab immediately afterwards.
                    homePageRemoteMessaging.networkProtectionRemoteMessaging.dismiss(message: remoteMessage)
                    refreshFeaturesMatrix()
                }
            }
        }

        @MainActor private func handle(remoteMessage: DataBrokerProtectionRemoteMessage) {
#if DBP
            guard let actionType = remoteMessage.action.actionType else {
                PixelKit.fire(GeneralPixel.dataBrokerProtectionRemoteMessageDismissed(messageID: remoteMessage.id))
                homePageRemoteMessaging.dataBrokerProtectionRemoteMessaging.dismiss(message: remoteMessage)
                refreshFeaturesMatrix()
                return
            }

            switch actionType {
            case .openDataBrokerProtection:
                break // Not used currently
            case .openSurveyURL, .openURL:
                if let surveyURL = remoteMessage.presentableSurveyURL() {
                    let tab = Tab(content: .url(surveyURL, source: .ui), shouldLoadInBackground: true)
                    tabCollectionViewModel.append(tab: tab)
                    PixelKit.fire(GeneralPixel.dataBrokerProtectionRemoteMessageOpened(messageID: remoteMessage.id))

                    // Dismiss the message after the user opens the URL, even if they just close the tab immediately afterwards.
                    homePageRemoteMessaging.dataBrokerProtectionRemoteMessaging.dismiss(message: remoteMessage)
                    refreshFeaturesMatrix()
                }
            }
#endif
        }
    }

    // MARK: Feature Type
    enum FeatureType: CaseIterable, Equatable, Hashable {

        // CaseIterable doesn't work with enums that have associated values, so we have to implement it manually.
        // We ignore the `networkProtectionRemoteMessage` case here to avoid it getting accidentally included - it has special handling and will get
        // included elsewhere.
        static var allCases: [HomePage.Models.FeatureType] {
            [.duckplayer, .emailProtection, .defaultBrowser, .dock, .importBookmarksAndPasswords, .surveyDay0, .surveyDay14]
        }

        case duckplayer
        case emailProtection
        case defaultBrowser
        case dock
        case importBookmarksAndPasswords
        case surveyDay0
        case surveyDay14
        case networkProtectionRemoteMessage(NetworkProtectionRemoteMessage)
        case dataBrokerProtectionRemoteMessage(DataBrokerProtectionRemoteMessage)
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
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0CardTitle
            case .surveyDay14:
                return UserText.newTabSetUpSurveyDay14CardTitle
            case .networkProtectionRemoteMessage(let message):
                return message.cardTitle
            case .dataBrokerProtectionRemoteMessage(let message):
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
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0Summary
            case .surveyDay14:
                return UserText.newTabSetUpSurveyDay14Summary
            case .networkProtectionRemoteMessage(let message):
                return message.cardDescription
            case .dataBrokerProtectionRemoteMessage(let message):
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
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0Action
            case .surveyDay14:
                return UserText.newTabSetUpSurveyDay14Action
            case .networkProtectionRemoteMessage(let message):
                return message.action.actionTitle
            case .dataBrokerProtectionRemoteMessage(let message):
                return message.action.actionTitle
            case .dataBrokerProtectionWaitlistInvited:
                return "Get Started"
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
            case .surveyDay0:
                return .qandA128.resized(to: iconSize)!
            case .surveyDay14:
                return .qandA128.resized(to: iconSize)!
            case .networkProtectionRemoteMessage:
                return .vpnEnded.resized(to: iconSize)!
            case .dataBrokerProtectionRemoteMessage:
                return .dbpInformationRemover.resized(to: iconSize)!
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

struct HomePageRemoteMessaging {

    static func defaultMessaging() -> HomePageRemoteMessaging {
#if DBP
        return HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: DefaultNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: .netP,
            dataBrokerProtectionRemoteMessaging: DefaultDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: .dbp
        )
#else
        return HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: DefaultNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: .netP
        )
#endif
    }

    let networkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging
    let networkProtectionUserDefaults: UserDefaults

#if DBP
    let dataBrokerProtectionRemoteMessaging: DataBrokerProtectionRemoteMessaging
    let dataBrokerProtectionUserDefaults: UserDefaults
#endif

}

public protocol RandomNumberGenerating {
    func random(in range: Range<Int>) -> Int
}

struct RandomNumberGenerator: RandomNumberGenerating {
    func random(in range: Range<Int>) -> Int {
        return Int.random(in: range)
    }
}
