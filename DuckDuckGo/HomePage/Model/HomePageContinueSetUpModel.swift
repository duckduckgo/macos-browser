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

#if NETWORK_PROTECTION
import NetworkProtection
import NetworkProtectionUI
#endif

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

#if NETWORK_PROTECTION
        let networkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging
        let appGroupUserDefaults: UserDefaults
#endif

        var isDay0SurveyEnabled: Bool {
            let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
            if let day0SurveyString =  newTabContinueSetUpSettings["surveyCardDay0"] as? String {
                if day0SurveyString == "enabled" {
                    return true
                }
            }
            return false
        }
        var isDay7SurveyEnabled: Bool {
            let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
            if let day7SurveyString =  newTabContinueSetUpSettings["surveyCardDay7"] as? String {
                if day7SurveyString == "enabled" {
                    return true
                }
            }
            return false
        }
        var duckPlayerURL: String {
            let duckPlayerSettings = privacyConfigurationManager.privacyConfig.settings(for: .duckPlayer)
            return duckPlayerSettings["tryDuckPlayerLink"] as? String ?? "https://www.youtube.com/watch?v=yKWIA-Pys4c"
        }
        var day0SurveyURL: String = "https://selfserve.decipherinc.com/survey/selfserve/32ab/230701?list=1"
        var day7SurveyURL: String = "https://selfserve.decipherinc.com/survey/selfserve/32ab/230702?list=1"

        private let defaultBrowserProvider: DefaultBrowserProvider
        private let dataImportProvider: DataImportStatusProviding
        private let tabCollectionViewModel: TabCollectionViewModel
        private let emailManager: EmailManager
        private let privacyPreferences: PrivacySecurityPreferences
        private let cookieConsentPopoverManager: CookieConsentPopoverManager
        private let duckPlayerPreferences: DuckPlayerPreferencesPersistor
        private var cookiePopUpVisible = false

        weak var delegate: ContinueSetUpVewModelDelegate?

        @UserDefaultsWrapper(key: .homePageShowAllFeatures, defaultValue: false)
        var shouldShowAllFeatures: Bool {
            didSet {
                updateVisibleMatrix()
            }
        }

        @UserDefaultsWrapper(key: .homePageShowMakeDefault, defaultValue: true)
        private var shouldShowMakeDefaultSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowImport, defaultValue: true)
        private var shouldShowImportSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowDuckPlayer, defaultValue: true)
        private var shouldShowDuckPlayerSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowEmailProtection, defaultValue: true)
        private var shouldShowEmailProtectionSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowCookie, defaultValue: true)
        private var shouldShowCookieSetting: Bool

        @UserDefaultsWrapper(key: .homePageShowSurveyDay0, defaultValue: true)
        private var shouldShowSurveyDay0: Bool

        @UserDefaultsWrapper(key: .homePageUserInteractedWithSurveyDay0, defaultValue: false)
        private var userInteractedWithSurveyDay0: Bool

        @UserDefaultsWrapper(key: .shouldShowDBPWaitlistInvitedCardUI, defaultValue: false)
        private var shouldShowDBPWaitlistInvitedCardUI: Bool

        @UserDefaultsWrapper(key: .homePageShowSurveyDay7, defaultValue: true)
        private var shouldShowSurveyDay7: Bool

        @UserDefaultsWrapper(key: .homePageIsFirstSession, defaultValue: true)
        private var isFirstSession: Bool

        @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        private var firstLaunchDate: Date

        @UserDefaultsWrapper(key: .shouldShowNetworkProtectionSystemExtensionUpgradePrompt, defaultValue: true)
        private var shouldShowNetworkProtectionSystemExtensionUpgradePrompt: Bool

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

#if NETWORK_PROTECTION
        init(defaultBrowserProvider: DefaultBrowserProvider,
             dataImportProvider: DataImportStatusProviding,
             tabCollectionViewModel: TabCollectionViewModel,
             emailManager: EmailManager = EmailManager(),
             privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared,
             cookieConsentPopoverManager: CookieConsentPopoverManager = CookieConsentPopoverManager(),
             duckPlayerPreferences: DuckPlayerPreferencesPersistor,
             networkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging,
             appGroupUserDefaults: UserDefaults,
             privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.privacyPreferences = privacyPreferences
            self.cookieConsentPopoverManager = cookieConsentPopoverManager
            self.duckPlayerPreferences = duckPlayerPreferences
            self.networkProtectionRemoteMessaging = networkProtectionRemoteMessaging
            self.appGroupUserDefaults = appGroupUserDefaults
            self.privacyConfigurationManager = privacyConfigurationManager
            refreshFeaturesMatrix()
            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }
#else
        init(defaultBrowserProvider: DefaultBrowserProvider,
             dataImportProvider: DataImportStatusProviding,
             tabCollectionViewModel: TabCollectionViewModel,
             emailManager: EmailManager = EmailManager(),
             privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared,
             cookieConsentPopoverManager: CookieConsentPopoverManager = CookieConsentPopoverManager(),
             duckPlayerPreferences: DuckPlayerPreferencesPersistor,
             privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.privacyPreferences = privacyPreferences
            self.cookieConsentPopoverManager = cookieConsentPopoverManager
            self.duckPlayerPreferences = duckPlayerPreferences
            self.privacyConfigurationManager = privacyConfigurationManager
            refreshFeaturesMatrix()
            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }
#endif

        // swiftlint:disable cyclomatic_complexity
        @MainActor func performAction(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                do {
                    try defaultBrowserProvider.presentDefaultBrowserPrompt()
                } catch {
                    defaultBrowserProvider.openSystemPreferences()
                }
            case .importBookmarksAndPasswords:
                dataImportProvider.showImportWindow(completion: {self.refreshFeaturesMatrix()})
            case .duckplayer:
                if let videoUrl = URL(string: duckPlayerURL) {
                    let tab = Tab(content: .url(videoUrl), shouldLoadInBackground: true)
                    tabCollectionViewModel.append(tab: tab)
                }
            case .emailProtection:
                let tab = Tab(content: .url(EmailUrls().emailProtectionLink), shouldLoadInBackground: true)
                tabCollectionViewModel.append(tab: tab)
            case .cookiePopUp:
                if !cookiePopUpVisible {
                    delegate?.showCookieConsentPopUp(manager: cookieConsentPopoverManager, completion: { [weak self] result in
                        guard let self = self else {
                            return
                        }
                        self.privacyPreferences.autoconsentEnabled = result
                        self.refreshFeaturesMatrix()
                        self.cookiePopUpVisible = false
                    })
                    cookiePopUpVisible = true
                }
            case .surveyDay0:
                visitSurvey(day: .day0)
            case .surveyDay7:
                visitSurvey(day: .day7)
            case .networkProtectionRemoteMessage(let message):
                handle(remoteMessage: message)
            case .networkProtectionSystemExtensionUpgrade:
#if NETWORK_PROTECTION
                NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: nil)
#endif
            case .dataBrokerProtectionWaitlistInvited:
#if DBP
                DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .cardUI)
#endif
            }
        }
        // swiftlint:enable cyclomatic_complexity

        func removeItem(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                shouldShowMakeDefaultSetting = false
            case .importBookmarksAndPasswords:
                shouldShowImportSetting = false
            case .duckplayer:
                shouldShowDuckPlayerSetting = false
            case .emailProtection:
                shouldShowEmailProtectionSetting = false
            case .cookiePopUp:
                shouldShowCookieSetting = false
            case .surveyDay0:
                shouldShowSurveyDay0 = false
            case .surveyDay7:
                shouldShowSurveyDay7 = false
            case .networkProtectionRemoteMessage(let message):
#if NETWORK_PROTECTION
                networkProtectionRemoteMessaging.dismiss(message: message)
                Pixel.fire(.networkProtectionRemoteMessageDismissed(messageID: message.id))
#endif
            case .networkProtectionSystemExtensionUpgrade:
                shouldShowNetworkProtectionSystemExtensionUpgradePrompt = false
            case .dataBrokerProtectionWaitlistInvited:
                shouldShowDBPWaitlistInvitedCardUI = false
            }
            refreshFeaturesMatrix()
        }

        // swiftlint:disable cyclomatic_complexity function_body_length
        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []
#if DBP
            if shouldDBPWaitlistCardBeVisible {
                features.append(.dataBrokerProtectionWaitlistInvited)
            }
#endif

#if NETWORK_PROTECTION

            // Only show the upgrade card to users who have used the VPN before:
            let activationStore = DefaultWaitlistActivationDateStore()
            if shouldShowNetworkProtectionSystemExtensionUpgradePrompt,
               appGroupUserDefaults.networkProtectionOnboardingStatusRawValue != OnboardingStatus.completed.rawValue,
               activationStore.daysSinceActivation() != nil {
                features.append(.networkProtectionSystemExtensionUpgrade)
            }

            for message in networkProtectionRemoteMessaging.presentableRemoteMessages() {
                features.append(.networkProtectionRemoteMessage(message))
                DailyPixel.fire(
                    pixel: .networkProtectionRemoteMessageDisplayed(messageID: message.id),
                    frequency: .dailyOnly,
                    includeAppVersionParameter: true
                )
            }
#endif

            for feature in listOfFeatures {
                switch feature {
                case .defaultBrowser:
                    if shouldMakeDefaultCardBeVisible {
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
                case .cookiePopUp:
                    if shouldCookieCardBeVisible {
                        features.append(feature)
                    }
                case .surveyDay0:
                    if shouldSurveyDay0BeVisible {
                        features.append(feature)
                    }
                case .surveyDay7:
                    if shouldSurveyDay7BeVisible {
                        features.append(feature)
                    }
                case .networkProtectionRemoteMessage, .networkProtectionSystemExtensionUpgrade:
                    break // Do nothing, NetP remote messages get appended first
                case .dataBrokerProtectionWaitlistInvited:
                    break // Do nothing. The feature is being set for everyone invited in the waitlist
                }
            }
            featuresMatrix = features.chunked(into: itemsPerRow)
        }
        // swiftlint:enable cyclomatic_complexity function_body_length

        // Helper Functions
        @objc private func newTabOpenNotification(_ notification: Notification) {
            if !isFirstSession {
                listOfFeatures = randomisedFeatures
            }
#if DEBUG
            isFirstSession = false
#endif
            if OnboardingViewModel().onboardingFinished {
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
            var features: [FeatureType] = FeatureType.allCases.filter { $0 != .duckplayer && $0 != .cookiePopUp }
            features.insert(.duckplayer, at: 0)
            features.insert(.cookiePopUp, at: 1)
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
            !PixelExperiment.isNoCardsExperimentOn &&
            shouldShowMakeDefaultSetting &&
            !defaultBrowserProvider.isDefault
        }

        private var shouldImportCardBeVisible: Bool {
            !PixelExperiment.isNoCardsExperimentOn &&
            shouldShowImportSetting &&
            !dataImportProvider.didImport
        }

        private var shouldDuckPlayerCardBeVisible: Bool {
            !PixelExperiment.isNoCardsExperimentOn &&
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
            !PixelExperiment.isNoCardsExperimentOn &&
            shouldShowEmailProtectionSetting &&
            !emailManager.isSignedIn
        }

        private var shouldCookieCardBeVisible: Bool {
            !PixelExperiment.isNoCardsExperimentOn &&
            shouldShowCookieSetting &&
            privacyPreferences.autoconsentEnabled != true
        }

        private var shouldSurveyDay0BeVisible: Bool {
            let oneDayAgo = Calendar.current.date(byAdding: .weekday, value: -1, to: Date())!
            return !PixelExperiment.isNoCardsExperimentOn &&
            isDay0SurveyEnabled &&
            shouldShowSurveyDay0 &&
            !userInteractedWithSurveyDay0 &&
            firstLaunchDate > oneDayAgo
        }

        private var shouldSurveyDay7BeVisible: Bool {
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
            return !PixelExperiment.isNoCardsExperimentOn &&
            isDay7SurveyEnabled &&
            shouldShowSurveyDay0 &&
            shouldShowSurveyDay7 &&
            !userInteractedWithSurveyDay0 &&
            firstLaunchDate <= oneWeekAgo
        }

        private enum SurveyDay {
            case day0
            case day7
        }

        @MainActor private func visitSurvey(day: SurveyDay) {
            var surveyURLString: String
            switch day {
            case .day0:
                surveyURLString = day0SurveyURL
            case .day7:
                surveyURLString = day7SurveyURL
            }
            if let atb = statisticsStore.atb {
                surveyURLString += "&atb=\(atb)"
            }

            if let url = URL(string: surveyURLString) {
                let tab = Tab(content: .url(url), shouldLoadInBackground: true)
                tabCollectionViewModel.append(tab: tab)
                switch day {
                case .day0:
                    userInteractedWithSurveyDay0 = true
                case .day7:
                    shouldShowSurveyDay7 = false
                }
            }
        }

        @MainActor private func handle(remoteMessage: NetworkProtectionRemoteMessage) {
#if NETWORK_PROTECTION
            guard let actionType = remoteMessage.action.actionType else {
                Pixel.fire(.networkProtectionRemoteMessageDismissed(messageID: remoteMessage.id))
                networkProtectionRemoteMessaging.dismiss(message: remoteMessage)
                refreshFeaturesMatrix()
                return
            }

            switch actionType {
            case .openNetworkProtection:
                NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: nil)
            case .openSurveyURL, .openURL:
                if let surveyURL = remoteMessage.presentableSurveyURL() {
                    let tab = Tab(content: .url(surveyURL), shouldLoadInBackground: true)
                    tabCollectionViewModel.append(tab: tab)
                    Pixel.fire(.networkProtectionRemoteMessageOpened(messageID: remoteMessage.id))

                    // Dismiss the message after the user opens the URL, even if they just close the tab immediately afterwards.
                    networkProtectionRemoteMessaging.dismiss(message: remoteMessage)
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
            [.duckplayer, .cookiePopUp, .emailProtection, .defaultBrowser, .importBookmarksAndPasswords, .surveyDay0, .surveyDay7]
        }

        case duckplayer
        case cookiePopUp
        case emailProtection
        case defaultBrowser
        case importBookmarksAndPasswords
        case surveyDay0
        case surveyDay7
        case networkProtectionRemoteMessage(NetworkProtectionRemoteMessage)
        case networkProtectionSystemExtensionUpgrade
        case dataBrokerProtectionWaitlistInvited

        var title: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserCardTitle
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportCardTitle
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerCardTitle
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionCardTitle
            case .cookiePopUp:
                return UserText.newTabSetUpCookieManagerCardTitle
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0CardTitle
            case .surveyDay7:
                return UserText.newTabSetUpSurveyDay7CardTitle
            case .networkProtectionRemoteMessage(let message):
                return message.cardTitle
            case .networkProtectionSystemExtensionUpgrade:
                return "VPN Update Available"
            case .dataBrokerProtectionWaitlistInvited:
                return "Personal Information Removal"
            }
        }

        var summary: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserSummary
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportSummary
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerSummary
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionSummary
            case .cookiePopUp:
                return UserText.newTabSetUpCookieManagerSummary
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0Summary
            case .surveyDay7:
                return UserText.newTabSetUpSurveyDay7Summary
            case .networkProtectionRemoteMessage(let message):
                return message.cardDescription
            case .networkProtectionSystemExtensionUpgrade:
                return "Allow VPN system software again to continue testing Network Protection."
            case .dataBrokerProtectionWaitlistInvited:
                return "You're invited to try Personal Information Removal beta!"
            }
        }

        var action: String {
            switch self {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserAction
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportAction
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerAction
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionAction
            case .cookiePopUp:
                return UserText.newTabSetUpCookieManagerAction
            case .surveyDay0:
                return UserText.newTabSetUpSurveyDay0Action
            case .surveyDay7:
                return UserText.newTabSetUpSurveyDay7Action
            case .networkProtectionRemoteMessage(let message):
                return message.action.actionTitle
            case .networkProtectionSystemExtensionUpgrade:
                return "Update VPN"
            case .dataBrokerProtectionWaitlistInvited:
                return "Get Started"
            }
        }

        var icon: NSImage {
            let iconSize = NSSize(width: 64, height: 48)

            switch self {
            case .defaultBrowser:
                return NSImage(named: "Default-App-128")!.resized(to: iconSize)!
            case .importBookmarksAndPasswords:
                return NSImage(named: "Import-128")!.resized(to: iconSize)!
            case .duckplayer:
                return NSImage(named: "Clean-Tube-128")!.resized(to: iconSize)!
            case .emailProtection:
                return NSImage(named: "inbox-128")!.resized(to: iconSize)!
            case .cookiePopUp:
                return NSImage(named: "Cookie-Popups-128")!.resized(to: iconSize)!
            case .surveyDay0:
                return NSImage(named: "Survey-128")!.resized(to: iconSize)!
            case .surveyDay7:
                return NSImage(named: "Survey-128")!.resized(to: iconSize)!
            case .networkProtectionRemoteMessage, .networkProtectionSystemExtensionUpgrade:
                return NSImage(named: "VPN-Ended")!.resized(to: iconSize)!
            case .dataBrokerProtectionWaitlistInvited:
                return NSImage(named: "DBP-Information-Remover")!.resized(to: iconSize)!
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

// MARK: ContinueSetUpVewModelDelegate
protocol ContinueSetUpVewModelDelegate: AnyObject {
    func showCookieConsentPopUp(manager: CookieConsentPopoverManager, completion: ((Bool) -> Void)?)
}

extension HomePageViewController: ContinueSetUpVewModelDelegate {
    func showCookieConsentPopUp(manager: CookieConsentPopoverManager, completion: ((Bool) -> Void)?) {
        manager.show(on: self.view, animated: true, type: .setUp, result: completion)
    }
}
