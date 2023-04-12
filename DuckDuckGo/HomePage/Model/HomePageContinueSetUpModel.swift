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

extension HomePage.Models {

    final class ContinueSetUpModel: ObservableObject {

        let title = UserText.newTabSetUpSectionTitle
        let itemWidth = FeaturesGridDimensions.itemWidth
        let itemHeight = FeaturesGridDimensions.itemHeight
        let horizontalSpacing = FeaturesGridDimensions.horizontalSpacing
        let verticalSpacing = FeaturesGridDimensions.verticalSpacing
        let itemsPerRow = HomePage.featuresPerRow
        let gridWidth = FeaturesGridDimensions.width
        let deleteActionTitle = UserText.newTabSetUpRemoveItemAction

        let defaultBrowserProvider: DefaultBrowserProvider
        let dataImportProvider: DataImportProvider

        var shouldShowAllFeatures: Bool = false {
            didSet {
                updateVisibleMatrix()
            }
        }

        var isMorOrLessButtonNeeded: Bool {
            return featuresMatrix.count > 1
        }

        private var featuresMatrix: [[FeatureType]] = [[]] {
            didSet {
                updateVisibleMatrix()
            }
        }
        @Published var visibleFeaturesMatrix: [[FeatureType]] = [[]]

        init(defaultBrowserProvider: DefaultBrowserProvider, dataImportProvider: DataImportProvider) {
            self.defaultBrowserProvider = defaultBrowserProvider
            self.dataImportProvider = dataImportProvider
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
            case .coockiePopUp:
                return UserText.newTabSetUpCoockeManagerAction
            }
        }

        func performAction(for featureType: FeatureType) {
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
                print("\(featureType)")
            case .emailProtection:
                print("\(featureType)")
            case .coockiePopUp:
                print("\(featureType)")
            }
        }

        func removeItem() {

        }

        func refreshFeaturesMatrix() {
            var features: [FeatureType] = []
            for feature in FeatureType.allCases {
                switch feature {

                case .defaultBrowser:
                    if !defaultBrowserProvider.isDefault {
                        features.append(feature)
                    }
                case .importBookmarksAndPasswords:
                    if !dataImportProvider.hasUserUsedImport {
                        features.append(feature)
                    }
                case .duckplayer:
                    features.append(feature)
                case .emailProtection:
                    features.append(feature)
                case .coockiePopUp:
                    features.append(feature)
                }
            }
            featuresMatrix = features.chunked(into: HomePage.featuresPerRow)
        }

        private func updateVisibleMatrix() {
            visibleFeaturesMatrix = shouldShowAllFeatures ? featuresMatrix : [featuresMatrix[0]]
        }

    }

    enum FeatureType: CaseIterable {
        case defaultBrowser
        case importBookmarksAndPasswords
        case duckplayer
        case emailProtection
        case coockiePopUp

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
            case .coockiePopUp:
                return UserText.newTabSetUpCookieManagerCardTitle
            }
        }

        // Still Waiting for icon assets
        var icon: NSImage {
            switch self {
            case .defaultBrowser:
                return NSImage(named: "CookieBite")!
            case .importBookmarksAndPasswords:
                return NSImage(named: "CookieBite")!
            case .duckplayer:
                return NSImage(named: "CookieBite")!
            case .emailProtection:
                return NSImage(named: "CookieBite")!
            case .coockiePopUp:
                return NSImage(named: "CookieBite")!
            }
        }
    }

    enum FeaturesGridDimensions {
        static let itemWidth: CGFloat = 160
        static let itemHeight: CGFloat = 64
        static let verticalSpacing: CGFloat = 10
        static let horizontalSpacing: CGFloat = 12

        static let width: CGFloat = (itemWidth + horizontalSpacing) * CGFloat(HomePage.featuresPerRow) - horizontalSpacing

        static func height(for rowCount: Int) -> CGFloat {
            (itemHeight + verticalSpacing) * CGFloat(rowCount) - verticalSpacing
        }
    }
}
