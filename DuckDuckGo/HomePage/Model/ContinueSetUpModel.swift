//
//  HomePageExploreDucjDuckGoViewModel.swift
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
        let itemWidth = GridDimensions.itemWidth
        let itemHeight = GridDimensions.itemHeight
        let horizontalSpacing = GridDimensions.horizontalSpacing
        let verticalSpacing = GridDimensions.verticalSpacing
        let itemsPerRow = HomePage.featuresPerRow
        let gridWidth = GridDimensions.width
        let deleteActionTitle = UserText.newTabSetUpRemoveItemAction

        var showAllFeatures: Bool = false {
            didSet {
                visibleFeaturesMatrix = showAllFeatures ? featuresMatrix : [featuresMatrix[0]]
            }
        }

        private var featuresMatrix = FeatureType.allCases.chunked(into: HomePage.featuresPerRow)
        @Published var visibleFeaturesMatrix: [[FeatureType]] = [[]]

        init() {
            visibleFeaturesMatrix = [featuresMatrix[0]]
        }

        func actionTitle(for featureTye: FeatureType) -> String {
            switch featureTye {
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

        }

        func removeItem() {

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

    enum GridDimensions {
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
