//
//  HomeContentSectionsView.swift
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

import SwiftUIExtensions

extension HomePage.Views {

    struct HomeContentSectionsView: View {
        let includeContinueSetUpCards: Bool
        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var addressBarModel: HomePage.Models.AddressBarModel
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        let iconSize: CGFloat = 16

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if addressBarModel.shouldShowAddressBar {
                    Toggle(isOn: $model.isSearchBarVisible) {
                        HStack {
                            Image(.searchBookmarks)
                                .frame(width: iconSize, height: iconSize)
                            Text(UserText.newTabSearchBarSectionTitle)
                            Spacer()
                        }
                    }
                    .toggleStyle(.switch)
                }

                if includeContinueSetUpCards {
                    Toggle(isOn: $model.isContinueSetUpVisible) {
                        HStack {
                            Image(.rocketGrayscale)
                                .frame(width: iconSize, height: iconSize)
                            Text(UserText.newTabSetUpSectionTitle)
                            Spacer()
                        }
                    }
                    .toggleStyle(.switch)
                    .visibility(continueSetUpModel.hasContent ? .visible : .gone)
                }

                Toggle(isOn: $model.isFavoriteVisible) {
                    HStack {
                        Image(.favorite)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabFavoriteSectionTitle)
                        Spacer()
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $model.isRecentActivityVisible) {
                    HStack {
                        Image(.shield)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabRecentActivitySectionTitle)
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
}
