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

import Foundation
import BrowserServicesKit

extension HomePage.Models {

    final class ContinueSetUpModel: ObservableObject {
        let title = UserText.newTabSetUpSectionTitle
        let itemWidth = FeaturesGridDimensions.itemWidth
        let itemHeight = FeaturesGridDimensions.itemHeight
        let horizontalSpacing = FeaturesGridDimensions.horizontalSpacing
        let verticalSpacing = FeaturesGridDimensions.verticalSpacing
        let itemsPerRow = 2
        let gridWidth = FeaturesGridDimensions.width
        let deleteActionTitle = UserText.newTabSetUpRemoveItemAction

        let privacyConfig = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig
        var duckPlayerURL: String {
            let duckPlayerSettings = privacyConfig.settings(for: .duckPlayer)
            return duckPlayerSettings["tryDuckPlayerLink"] as? String ?? "https://www.youtube.com/watch?v=yKWIA-Pys4c"
        }

        private let defaultBrowserProvider: DefaultBrowserProvider
        private let dataImportProvider: DataImportStatusProviding
        private let tabCollectionViewModel: TabCollectionViewModel
        private let emailManager: EmailManager
        private let privacyPreferences: PrivacySecurityPreferences
        private let cookieConsentPopoverManager: CookieConsentPopoverManager
        private let duckPlayerPreferences: DuckPlayerPreferencesPersistor
        private var cookiePopUpVisible = false

        weak var delegate: ContinueSetUpVewModelDelegate?

        @UserDefaultsWrapper(key: .homePageShowAllFeatures, defaultValue: true)
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

        var isMoreOrLessButtonNeeded: Bool {
            print(featuresMatrix.count)
            return featuresMatrix.count > 1
        }

        var hasContent: Bool {
            return !featuresMatrix.isEmpty
        }

        private var featuresMatrix: [[FeatureType]] = [[]] {
            didSet {
                updateVisibleMatrix()
            }
        }

        private var showRemoveItemButtonTimer: Timer?

        var isHoveringOverItem: Bool = false {
            didSet {
                if isHoveringOverItem {
                    showRemoveItemButtonTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false, block: { _ in
                        self.isRemoveItemButtonVisible = true
                    })
                } else {
                    showRemoveItemButtonTimer?.invalidate()
                    isRemoveItemButtonVisible = false
                }
            }
        }

        @Published var isRemoveItemButtonVisible = false

        @Published var visibleFeaturesMatrix: [[FeatureType]] = [[]]

        init(defaultBrowserProvider: DefaultBrowserProvider,
             dataImportProvider: DataImportStatusProviding,
             tabCollectionViewModel: TabCollectionViewModel,
             emailManager: EmailManager = EmailManager(),
             privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared,
             cookieConsentPopoverManager: CookieConsentPopoverManager = CookieConsentPopoverManager(),
             duckPlayerPreferences: DuckPlayerPreferencesPersistor) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dataImportProvider = dataImportProvider
            self.tabCollectionViewModel = tabCollectionViewModel
            self.emailManager = emailManager
            self.privacyPreferences = privacyPreferences
            self.cookieConsentPopoverManager = cookieConsentPopoverManager
            self.duckPlayerPreferences = duckPlayerPreferences
            refreshFeaturesMatrix()
        }

        func actionTitle(for featureType: FeatureType) -> String {
            switch featureType {
            case .defaultBrowser:
                return UserText.newTabSetUpDefaultBrowserAction
            case .importBookmarksAndPasswords:
                return UserText.newTabSetUpImportAction
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerAction
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionAction
            case .cookiePopUp:
                return UserText.newTabSetUpCoockeManagerAction
            }
        }

        @MainActor func performAction(for featureType: FeatureType) {
            switch featureType {
            case .defaultBrowser:
                do {
                    try defaultBrowserProvider.presentDefaultBrowserPrompt()
                } catch {
                    defaultBrowserProvider.openSystemPreferences()
                }
            case .importBookmarksAndPasswords:
                dataImportProvider.showImportWindow(completion: refreshFeaturesMatrix)
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
            case .cookiePopUp:
                shouldShowCookieSetting = false
            }
            refreshFeaturesMatrix()
        }

        // swiftlint:disable cyclomatic_complexity
        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []
            for feature in FeatureType.allCases {
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
                }
            }
            featuresMatrix = features.chunked(into: itemsPerRow)
        }
        // swiftlint:enable cyclomatic_complexity

        // Helper Functions
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

        private var shouldEmailProtectionCardBeVisible: Bool {
            shouldShowEmailProtectionSetting &&
            !emailManager.isSignedIn
        }

        private var shouldCookieCardBeVisible: Bool {
            shouldShowCookieSetting &&
            privacyPreferences.autoconsentEnabled != true
        }

    }

    // MARK: Feature Type
    enum FeatureType: CaseIterable {
        case defaultBrowser
        case importBookmarksAndPasswords
        case duckplayer
        case emailProtection
        case cookiePopUp

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
            }
        }

        var summary: String {
            switch self {
            case .defaultBrowser:
                return "We automatically block trackers as you browse. It's privacy, simplified."
            case .importBookmarksAndPasswords:
                return "Import all your bookmarks and passwords for a smooth transition."
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerCardTitle
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionCardTitle
            case .cookiePopUp:
                return UserText.newTabSetUpCookieManagerCardTitle
            }
        }

        var action: String {
            switch self {
            case .defaultBrowser:
                return "Set as Default"
            case .importBookmarksAndPasswords:
                return "Import Now"
            case .duckplayer:
                return UserText.newTabSetUpDuckPlayerCardTitle
            case .emailProtection:
                return UserText.newTabSetUpEmailProtectionCardTitle
            case .cookiePopUp:
                return UserText.newTabSetUpCookieManagerCardTitle
            }
        }

        var icon: NSImage {
            let iconSize = NSSize(width: 28, height: 28)

            switch self {
            case .defaultBrowser:
                return NSImage(named: "DefaultBrowser")!.resized(to: iconSize)!
            case .importBookmarksAndPasswords:
                return NSImage(named: "Bookmark-Import-Multicolor")!.resized(to: iconSize)!
            case .duckplayer:
                return NSImage(named: "VideoPlayer-Multicolor")!.resized(to: iconSize)!
            case .emailProtection:
                return NSImage(named: "Email-Protection-Multicolor")!.resized(to: iconSize)!
            case .cookiePopUp:
                return NSImage(named: "Cookie-Multicolor")!.resized(to: iconSize)!
            }
        }
    }

    enum FeaturesGridDimensions {
        static let itemWidth: CGFloat = 240
        static let itemHeight: CGFloat = 113
        static let verticalSpacing: CGFloat = 10
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
