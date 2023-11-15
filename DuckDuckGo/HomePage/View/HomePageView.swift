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
        static let targetWidth: CGFloat = 508
        let isBurner: Bool

        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel

        @State private var isHomeContentPopoverVisible = false

        var body: some View {
            if isBurner {
                BurnerHomePageView()
            } else {
                regularHomePageView(includingContinueSetUpCards: model.isContinueSetUpAvailable)
                    .contextMenu(ContextMenu(menuItems: {
                        if model.isContinueSetUpAvailable {
                            Toggle(UserText.newTabMenuItemShowContinuteSetUp, isOn: $model.isContinueSetUpVisible)
                                .toggleStyle(.checkbox)
                                .visibility(continueSetUpModel.hasContent ? .visible : .gone)
                        }
                        Toggle(UserText.newTabMenuItemShowFavorite, isOn: $model.isFavoriteVisible)
                            .toggleStyle(.checkbox)
                        Toggle(UserText.newTabMenuItemShowRecentActivity, isOn: $model.isRecentActivityVisible)
                            .toggleStyle(.checkbox)
                    }))
            }
        }

        func regularHomePageView(includingContinueSetUpCards: Bool) -> some View {
            ZStack(alignment: .top) {

                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            if includingContinueSetUpCards {
                                ContinueSetUpView()
                                    .padding(.top, 64)
                                    .visibility(model.isContinueSetUpVisible ? .visible : .gone)
                            } else {
                                DefaultBrowserPrompt()
                            }

                            Favorites()
                                .padding(.top, 24)
                                .visibility(model.isFavoriteVisible ? .visible : .gone)

                            RecentlyVisited()
                                .padding(.top, 24)
                                .padding(.bottom, 16)
                                .visibility(model.isRecentActivityVisible ? .visible : .gone)

                        }
                        .frame(width: Self.targetWidth)
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HomeContentButtonView(isHomeContentPopoverVisible: $isHomeContentPopoverVisible)
                            .padding(.bottom, 14)
                            .padding(.trailing, 14)
                            .popover(isPresented: $isHomeContentPopoverVisible, content: {
                                HomeContentPopoverView(includeContinueSetUpCards: includingContinueSetUpCards)
                                    .padding()
                                    .environmentObject(model)
                                    .environmentObject(continueSetUpModel)
                                    .environmentObject(favoritesModel)
                            })
                    }
                }

            }
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .onAppear {
                LocalBookmarkManager.shared.requestSync()
            }
        }

        struct HomeContentButtonView: View {
            let defaultColor: Color = Color("NewTabPageBackgroundColor")
            let onHoverColor: Color = Color("ButtonMouseOverColor")
            let onSelectedColor: Color = Color("ButtonMouseDownColor")
            let iconSize = 16.02
            let targetSize = 28.0

            @State var isHovering: Bool = false
            @Binding var isHomeContentPopoverVisible: Bool

            private var buttonBackgroundColor: Color {
                if isHomeContentPopoverVisible {
                    return onSelectedColor
                }
                if isHovering {
                    return onHoverColor
                }
                return defaultColor
            }

            var body: some View {
                ZStack {
                    Rectangle()
                        .fill(buttonBackgroundColor)
                        .frame(width: targetSize, height: targetSize, alignment: .bottomTrailing)
                        .cornerRadius(3)
                    Image("OptionsMainView")
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .scaledToFit()
                        .link(onHoverChanged: nil) {
                            isHomeContentPopoverVisible.toggle()
                        }
                    .onHover { isHovering in
                        self.isHovering = isHovering
                    }
                }
            }
        }
    }

    struct HomeContentPopoverView: View {
        let includeContinueSetUpCards: Bool
        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        let iconSize = 16.02

        var body: some View {
            Text(UserText.newTabBottomPopoverTitle)
                .bold()
                .font(.custom("SFProText-Regular", size: 13))
            Divider()
            if includeContinueSetUpCards {
                HStack {
                    Toggle(isOn: $model.isContinueSetUpVisible, label: {
                        HStack {
                            Image("RocketNoColor")
                                .frame(width: iconSize, height: iconSize)
                            Text(UserText.newTabSetUpSectionTitle)
                        }
                    })
                    .visibility(continueSetUpModel.hasContent ? .visible : .gone)
                    Spacer()
                }
            }
            HStack {
                Toggle(isOn: $model.isFavoriteVisible, label: {
                    HStack {
                        Image("Favorite")
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabFavoriteSectionTitle)
                    }
                })
                Spacer()
            }
            HStack {
                Toggle(isOn: $model.isRecentActivityVisible, label: {
                    HStack {
                        Image("Shield")
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabRecentActivitySectionTitle)
                    }
                })
                Spacer()
            }
        }
    }
}
