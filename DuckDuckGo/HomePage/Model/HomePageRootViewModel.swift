//
//  HomePageRootViewModel.swift
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

    final class HomePageRootViewModel: ObservableObject {

        private var homePagePreferencesPersistor: HomePagePreferencesUserDefaultsPersistor

        init(homePagePreferencesPersistor: HomePagePreferencesUserDefaultsPersistor = HomePagePreferencesUserDefaultsPersistor()) {
            self.homePagePreferencesPersistor = homePagePreferencesPersistor
            isFavouriteVisible = homePagePreferencesPersistor.isFavouriteVisible
            isContinueSetUpVisible = homePagePreferencesPersistor.isContinueSetUpVisible
            isRecentActivityVisible = homePagePreferencesPersistor.isRecentActivityVisible
        }

        @Published var isFavouriteVisible: Bool {
            didSet {
                homePagePreferencesPersistor.isFavouriteVisible = isFavouriteVisible
                // Temporary Pixel
                if !isFavouriteVisible {
                    Pixel.fire(.favoriteSectionHidden)
                }
            }
        }

        @Published var isContinueSetUpVisible: Bool {
            didSet {
                homePagePreferencesPersistor.isContinueSetUpVisible = isContinueSetUpVisible
                // Temporary Pixel
                if !isContinueSetUpVisible {
                    Pixel.fire(.continueSetUpSectionHidden)
                }
            }
        }

        @Published var isRecentActivityVisible: Bool {
            didSet {
                homePagePreferencesPersistor.isRecentActivityVisible = isRecentActivityVisible
                // Temporary Pixel
                if !isRecentActivityVisible {
                    Pixel.fire(.recentActivitySectionHidden)
                }
            }
        }

    }

    struct HomePagePreferencesUserDefaultsPersistor {

        @UserDefaultsWrapper(key: .homePageIsFavoriteVisible, defaultValue: true)
        var isFavouriteVisible: Bool

        @UserDefaultsWrapper(key: .homePageIsContinueSetupVisible, defaultValue: true)
        var isContinueSetUpVisible: Bool

        @UserDefaultsWrapper(key: .homePageIsRecentActivityVisible, defaultValue: true)
        var isRecentActivityVisible: Bool
    }
}
