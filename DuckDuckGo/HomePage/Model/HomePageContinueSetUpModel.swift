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
import Common

extension HomePage.Models {

    static let newHomePageTabOpen = Notification.Name("newHomePageAppOpen")

    final class ContinueSetUpModel: ObservableObject {
        let itemWidth = FeaturesGridDimensions.itemWidth
        let itemHeight = FeaturesGridDimensions.itemHeight
        let horizontalSpacing = FeaturesGridDimensions.horizontalSpacing
        let verticalSpacing = FeaturesGridDimensions.verticalSpacing
        let itemsPerRow = 2
        let gridWidth = FeaturesGridDimensions.width
        let deleteActionTitle = UserText.newTabSetUpRemoveItemAction
        let queue: DispatchQueue = DispatchQueue(label: "ContinueSetUp")

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

        @UserDefaultsWrapper(key: .homePageShowAddToDock, defaultValue: true)
        private var shouldShowAddToDockSetting: Bool

        @UserDefaultsWrapper(key: .homePageIsFirstSession, defaultValue: true)
        private var isFirstSession: Bool

        var isMoreOrLessButtonNeeded: Bool {
            return featuresMatrix.count > 1
        }

        var hasContent: Bool {
            return !featuresMatrix.isEmpty
        }

        private var wasAddedToDockInThisSession = false

        lazy var listOfFeatures = isFirstSession ? FeatureType.allCases: randomiseFeatures()

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
            NotificationCenter.default.addObserver(self, selector: #selector(newTabOpenNotification(_:)), name: HomePage.Models.newHomePageTabOpen, object: nil)
            isFirstSession = false
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
#if !APPSTORE
            case .addToDock:
                queue.async {
                    self.addToDock()
                }
#endif
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
#if !APPSTORE
            case .addToDock:
                shouldShowAddToDockSetting = false
#endif
            }
            refreshFeaturesMatrix()
        }

        // swiftlint:disable cyclomatic_complexity
        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []

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
#if !APPSTORE
                case .addToDock:
                    if shouldAddToDockCardBeVisible {
                        features.append(feature)
                    }
#endif
                }
            }
            featuresMatrix = features.chunked(into: itemsPerRow)
        }
        // swiftlint:enable cyclomatic_complexity

        // Helper Functions
        @objc private func newTabOpenNotification(_ notification: Notification) {
            listOfFeatures = randomiseFeatures()
        }

        private func randomiseFeatures() -> [FeatureType] {
            var features = FeatureType.allCases
            features.shuffle()
            for (index, feature) in features.enumerated() where feature == .defaultBrowser {
                features.remove(at: index)
                features.insert(feature, at: 0)
            }
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

        private var shouldEmailProtectionCardBeVisible: Bool {
            shouldShowEmailProtectionSetting &&
            !emailManager.isSignedIn
        }

        private var shouldCookieCardBeVisible: Bool {
            shouldShowCookieSetting &&
            privacyPreferences.autoconsentEnabled != true
        }

        private var shouldAddToDockCardBeVisible: Bool {
            shouldShowAddToDockSetting &&
            !isAppKeptInDock &&
            !wasAddedToDockInThisSession
        }

    }

    // MARK: Feature Type
    enum FeatureType: CaseIterable {
        case duckplayer
        case cookiePopUp
        case emailProtection
        case defaultBrowser
        case importBookmarksAndPasswords
#if !APPSTORE
        case addToDock
#endif
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
#if !APPSTORE
            case .addToDock:
                return UserText.newTabAddToDockCardTitle
#endif
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
#if !APPSTORE
            case .addToDock:
                return UserText.newTabAddToDockSummary
#endif
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
#if !APPSTORE
            case .addToDock:
                return UserText.newTabSetUpAddToDockAction
#endif
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
#if !APPSTORE
            case .addToDock:
                return NSImage(named: "Dock-128")!.resized(to: iconSize)!
#endif
            }
        }
    }

    enum FeaturesGridDimensions {
        static let itemWidth: CGFloat = 240
        static let itemHeight: CGFloat = 160
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

// MARK: Add to dock methods
extension HomePage.Models.ContinueSetUpModel {
    private var isAppKeptInDock: Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let preferencesPath = "\(NSHomeDirectory())/Library/Preferences/com.apple.dock.plist"

        if let dockPreferences = NSDictionary(contentsOfFile: preferencesPath),
           let persistentApps = dockPreferences["persistent-apps"] as? [NSDictionary] {
            for app in persistentApps {
                if let tileData = app["tile-data"] as? NSDictionary,
                   let appBundleIdentifier = tileData["bundle-identifier"] as? String,
                   appBundleIdentifier == bundleIdentifier {
                    return true
                }
            }
        }
        return false
    }

    private func addToDock() {
        let script = """
        on run
          set myapp to "\(Bundle.main.bundlePath)"
          try
            tell application "Dock" to quit
          end try
          do shell script "defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>" & myapp & "</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'"
          try
            tell application "Dock" to activate
          end try
        end run
        """

        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            _ = appleScript.executeAndReturnError(&errorInfo)

            if let error = errorInfo {
                let errorString = "Add to dock; script execution error: \(error)"
                os_log(.error, log: .default, "%{public}@", errorString)
            } else {
                self.wasAddedToDockInThisSession = true
                DispatchQueue.main.async {
                    self.refreshFeaturesMatrix()
                }
            }
        } else {
            let errorString = "Add to dock; failed to create NSAppleScript instance"
            os_log(.error, log: .default, "%{public}@", errorString)
        }
    }

}
