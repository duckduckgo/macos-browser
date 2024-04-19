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
        let permanentSurveyManager: SurveyManager

        var duckPlayerURL: String {
            let duckPlayerSettings = privacyConfigurationManager.privacyConfig.settings(for: .duckPlayer)
            return duckPlayerSettings["tryDuckPlayerLink"] as? String ?? "https://www.youtube.com/watch?v=yKWIA-Pys4c"
        }

        private let defaultBrowserProvider: DefaultBrowserProvider
        private let dataImportProvider: DataImportStatusProviding
        private let tabCollectionViewModel: TabCollectionViewModel
        private let emailManager: EmailManager
        private let duckPlayerPreferences: DuckPlayerPreferencesPersistor

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

        lazy var waitlistBetaThankYouPresenter = WaitlistThankYouPromptPresenter()

        lazy var listOfFeatures = isFirstSession ? firstRunFeatures : randomisedFeatures

        private var featuresMatrix: [[FeatureType]] = [[]] {
            didSet {
                updateVisibleMatrix()
            }
        }

        @Published var visibleFeaturesMatrix: [[FeatureType]] = [[]]

        init(defaultBrowserProvider: DefaultBrowserProvider,
             dataImportProvider: DataImportStatusProviding,
             tabCollectionViewModel: TabCollectionViewModel,
             emailManager: EmailManager = EmailManager(),
             duckPlayerPreferences: DuckPlayerPreferencesPersistor,
             homePageRemoteMessaging: HomePageRemoteMessaging,
             privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager,
             permanentSurveyManager: SurveyManager = PermanentSurveyManager()) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.duckPlayerPreferences = duckPlayerPreferences
            self.homePageRemoteMessaging = homePageRemoteMessaging
            self.privacyConfigurationManager = privacyConfigurationManager
            self.permanentSurveyManager = permanentSurveyManager

            refreshFeaturesMatrix()

            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }

        // swiftlint:disable:next cyclomatic_complexity
        @MainActor func performAction(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                do {
                    Pixel.fire(.defaultRequestedFromHomepageSetupView)
                    try defaultBrowserProvider.presentDefaultBrowserPrompt()
                } catch {
                    defaultBrowserProvider.openSystemPreferences()
                }
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
            case .permanentSurvey:
                visitSurvey()
            case .networkProtectionRemoteMessage(let message):
                handle(remoteMessage: message)
            case .dataBrokerProtectionRemoteMessage(let message):
                handle(remoteMessage: message)
            case .dataBrokerProtectionWaitlistInvited:
#if DBP
                DataBrokerProtectionAppEvents().handleWaitlistInvitedNotification(source: .cardUI)
#endif
            case .vpnThankYou:
                guard let window = NSApp.keyWindow,
                      case .normal = NSApp.runType else { return }
                waitlistBetaThankYouPresenter.presentVPNThankYouPrompt(in: window)
            case .pirThankYou:
                guard let window = NSApp.keyWindow,
                      case .normal = NSApp.runType else { return }
                waitlistBetaThankYouPresenter.presentPIRThankYouPrompt(in: window)
            }
        }

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
            case .permanentSurvey:
                shouldShowPermanentSurvey = false
            case .networkProtectionRemoteMessage(let message):
                homePageRemoteMessaging.networkProtectionRemoteMessaging.dismiss(message: message)
                Pixel.fire(.networkProtectionRemoteMessageDismissed(messageID: message.id))
            case .dataBrokerProtectionRemoteMessage(let message):
#if DBP
                homePageRemoteMessaging.dataBrokerProtectionRemoteMessaging.dismiss(message: message)
                Pixel.fire(.dataBrokerProtectionRemoteMessageDismissed(messageID: message.id))
#endif
            case .dataBrokerProtectionWaitlistInvited:
                shouldShowDBPWaitlistInvitedCardUI = false
            case .vpnThankYou:
                waitlistBetaThankYouPresenter.didDismissVPNThankYouCard()
            case .pirThankYou:
                waitlistBetaThankYouPresenter.didDismissPIRThankYouCard()
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
                DailyPixel.fire(
                    pixel: .dataBrokerProtectionRemoteMessageDisplayed(messageID: message.id),
                    frequency: .dailyOnly
                )
            }
#endif

            for message in homePageRemoteMessaging.networkProtectionRemoteMessaging.presentableRemoteMessages() {
                features.append(.networkProtectionRemoteMessage(message))
                DailyPixel.fire(
                    pixel: .networkProtectionRemoteMessageDisplayed(messageID: message.id),
                    frequency: .dailyOnly
                )
            }

            if waitlistBetaThankYouPresenter.canShowVPNCard {
                features.append(.vpnThankYou)
            }

            if waitlistBetaThankYouPresenter.canShowPIRCard {
                features.append(.pirThankYou)
            }

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
                case .permanentSurvey:
                    if shouldPermanentSurveyBeVisible {
                        features.append(feature)
                    }
                case .networkProtectionRemoteMessage,
                        .dataBrokerProtectionRemoteMessage,
                        .dataBrokerProtectionWaitlistInvited,
                        .vpnThankYou,
                        .pirThankYou:
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
            permanentSurveyManager.isSurveyAvailable
        }

        @MainActor private func visitSurvey() {
            guard let url = permanentSurveyManager.url else { return }

            let tab = Tab(content: .url(url, source: .ui), shouldLoadInBackground: true)
            tabCollectionViewModel.append(tab: tab)
            shouldShowPermanentSurvey = false
        }

        @MainActor private func handle(remoteMessage: NetworkProtectionRemoteMessage) {
            guard let actionType = remoteMessage.action.actionType else {
                Pixel.fire(.networkProtectionRemoteMessageDismissed(messageID: remoteMessage.id))
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
                    Pixel.fire(.networkProtectionRemoteMessageOpened(messageID: remoteMessage.id))

                    // Dismiss the message after the user opens the URL, even if they just close the tab immediately afterwards.
                    homePageRemoteMessaging.networkProtectionRemoteMessaging.dismiss(message: remoteMessage)
                    refreshFeaturesMatrix()
                }
            }
        }

        @MainActor private func handle(remoteMessage: DataBrokerProtectionRemoteMessage) {
#if DBP
            guard let actionType = remoteMessage.action.actionType else {
                Pixel.fire(.dataBrokerProtectionRemoteMessageDismissed(messageID: remoteMessage.id))
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
                    Pixel.fire(.dataBrokerProtectionRemoteMessageOpened(messageID: remoteMessage.id))

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
            [.duckplayer, .emailProtection, .defaultBrowser, .importBookmarksAndPasswords, .permanentSurvey]
        }

        case duckplayer
        case emailProtection
        case defaultBrowser
        case importBookmarksAndPasswords
        case permanentSurvey
        case networkProtectionRemoteMessage(NetworkProtectionRemoteMessage)
        case dataBrokerProtectionRemoteMessage(DataBrokerProtectionRemoteMessage)
        case dataBrokerProtectionWaitlistInvited
        case vpnThankYou
        case pirThankYou

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
            case .permanentSurvey:
                return PermanentSurveyManager.title
            case .networkProtectionRemoteMessage(let message):
                return message.cardTitle
            case .dataBrokerProtectionRemoteMessage(let message):
                return message.cardTitle
            case .dataBrokerProtectionWaitlistInvited:
                return "Personal Information Removal"
            case .vpnThankYou:
                return "Thanks for testing DuckDuckGo VPN!"
            case .pirThankYou:
                return "Thanks for testing Personal Information Removal!"
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
            case .permanentSurvey:
                return PermanentSurveyManager.body
            case .networkProtectionRemoteMessage(let message):
                return message.cardDescription
            case .dataBrokerProtectionRemoteMessage(let message):
                return message.cardDescription
            case .dataBrokerProtectionWaitlistInvited:
                return "You're invited to try Personal Information Removal beta!"
            case .vpnThankYou:
                return "To keep using it, subscribe to DuckDuckGo Privacy Pro."
            case .pirThankYou:
                return "To keep using it, subscribe to DuckDuckGo Privacy Pro."
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
            case .permanentSurvey:
                return PermanentSurveyManager.actionTitle
            case .networkProtectionRemoteMessage(let message):
                return message.action.actionTitle
            case .dataBrokerProtectionRemoteMessage(let message):
                return message.action.actionTitle
            case .dataBrokerProtectionWaitlistInvited:
                return "Get Started"
            case .vpnThankYou:
                return "See Special Offer For Testers"
            case .pirThankYou:
                return "See Special Offer For Testers"
            }
        }

        var icon: NSImage {
            let iconSize = NSSize(width: 64, height: 48)

            switch self {
            case .defaultBrowser:
                return .defaultApp128.resized(to: iconSize)!
            case .importBookmarksAndPasswords:
                return .import128.resized(to: iconSize)!
            case .duckplayer:
                return .cleanTube128.resized(to: iconSize)!
            case .emailProtection:
                return .inbox128.resized(to: iconSize)!
            case .permanentSurvey:
                return .survey128.resized(to: iconSize)!
            case .networkProtectionRemoteMessage:
                return .vpnEnded.resized(to: iconSize)!
            case .dataBrokerProtectionRemoteMessage:
                return .dbpInformationRemover.resized(to: iconSize)!
            case .dataBrokerProtectionWaitlistInvited:
                return .dbpInformationRemover.resized(to: iconSize)!
            case .vpnThankYou:
                return .vpnEnded.resized(to: iconSize)!
            case .pirThankYou:
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

extension AppVersion {
    public var majorAndMinorOSVersion: String {
        let components = osVersion.split(separator: ".")
        guard components.count >= 2 else {
            return majorVersionNumber
        }
        return "\(components[0]).\(components[1])"
    }
}
