//
//  HomePageView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import SwiftUI
import BrowserServicesKit
import SwiftUIExtensions

extension HomePage.Views {

struct RootView: View {

    let backgroundColor = Color("NewTabPageBackgroundColor")
    let targetWidth: CGFloat = 482

    @ObservedObject var model: HomePage.Models.HomePageRootViewModel
    @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
    @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel

    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .top) {

            ScrollView {
                VStack(spacing: 0) {
                    Group {
                        DefaultBrowserPrompt()

                        Favorites()
                            .padding(.top, 72)
                            .visibility(model.isFavouriteVisible ? .visible : .gone)

                        ContinueSetUpView()
                            .padding(.top, 72)
                            .visibility(model.isContinueSetUpVisible ? .visible : .gone)

                        RecentlyVisited()
                            .padding(.top, 66)
                            .padding(.bottom, 16)
                            .visibility(model.isRecentActivityVisible ? .visible : .gone)

                    }
                    .frame(width: 508)
                }
                .frame(maxWidth: .infinity)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    IconButton(icon: NSImage(named: "Options")!) {
                        isVisible.toggle()
                    }
                    .padding()
                    .popover(isPresented: $isVisible, content: {
                        HomeContnetPopoverView(isFavouriteVisible: $model.isFavouriteVisible, isContinueSetUpVisible: $model.isContinueSetUpVisible, isRecentActivityVisible: $model.isRecentActivityVisible)
                            .padding()
                    })
                }
            }

        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .contextMenu(ContextMenu(menuItems: {
            Toggle(UserText.newTabMenuItemShowFavorite, isOn: $model.isFavouriteVisible)
            .toggleStyle(.checkbox)
            .disabled(!favoritesModel.isThereContent)
            Toggle(UserText.newTabMenuItemShowContinuteSetUp, isOn: $model.isContinueSetUpVisible)
            .toggleStyle(.checkbox)
            .disabled(!continueSetUpModel.isThereContent)
            Toggle(UserText.newTabMenuItemShowRecentActivity, isOn: $model.isRecentActivityVisible)
            .toggleStyle(.checkbox)
        }))
     }
}

    struct HomeContnetPopoverView: View {
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        @Binding var isFavouriteVisible: Bool
        @Binding var isContinueSetUpVisible: Bool
        @Binding var isRecentActivityVisible: Bool

        var body: some View {
            Text(UserText.newTabBottomPopoverTitle)
                .bold()
                .font(.custom("SFProText-Regular", size: 13))
            Divider()
            HStack {
                Toggle(isOn: $isFavouriteVisible, label: {
                    HStack {
                        Image("Favorite")
                            .frame(width: 16.02, height: 16.02)
                        Text(UserText.newTabFavoriteSectionTitle)
                    }
                })
                .disabled(!favoritesModel.isThereContent)
                Spacer()
            }
            HStack {
                Toggle(isOn: $isContinueSetUpVisible, label: {
                    HStack {
                        Image("RocketNoColor")
                            .frame(width: 16.02, height: 16.02)
                        Text(UserText.newTabSetUpSectionTitle)
                    }
                })
                .disabled(!continueSetUpModel.isThereContent)
                Spacer()
            }
            HStack {
                Toggle(isOn: $isRecentActivityVisible, label: {
                    HStack {
                        Image("Shield")
                            .frame(width: 16.02, height: 16.02)
                        Text(UserText.newTabRecentActivitySectionTitle)
                    }
                })
                Spacer()
            }
        }
    }

}
