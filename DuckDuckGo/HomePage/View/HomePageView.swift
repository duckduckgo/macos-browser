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

import PixelKit
import RemoteMessaging
import SwiftUI
import SwiftUIExtensions

extension HomePage.Views {

    struct RootView: View {

        let backgroundColor: Color = .newTabPageBackground
        static let targetWidth: CGFloat = 508
        let isBurner: Bool

        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        @EnvironmentObject var activeRemoteMessageModel: ActiveRemoteMessageModel

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
                    VStack(spacing: 32) {
                        Spacer(minLength: 32)

                        Group {
                            remoteMessage()

                            if includingContinueSetUpCards {
                                ContinueSetUpView()
                                    .visibility(model.isContinueSetUpVisible ? .visible : .gone)
                                    .padding(.top, activeRemoteMessageModel.shouldShowRemoteMessage ? 24 : 0)
                            }

                            Favorites()
                                .visibility(model.isFavoriteVisible ? .visible : .gone)

                            RecentlyVisited()
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

        @ViewBuilder
        func remoteMessage() -> some View {
            if let remoteMessage = activeRemoteMessageModel.remoteMessage, let modelType = remoteMessage.content, modelType.isSupported {
                RemoteMessageView(viewModel: .init(
                    messageId: remoteMessage.id,
                    modelType: modelType,
                    onDidClose: { action in
                        activeRemoteMessageModel.dismissRemoteMessage(with: action)
                    },
                    onDidAppear: {
                        activeRemoteMessageModel.isViewOnScreen = true
                    },
                    onDidDisappear: {
                        activeRemoteMessageModel.isViewOnScreen = false
                    },
                    openURLHandler: { url in
                        WindowControllersManager.shared.showTab(with: .contentFromURL(url, source: .appOpenUrl))
                }))
            } else {
                EmptyView()
            }
        }

        struct HomeContentButtonView: View {
            let defaultColor: Color = .newTabPageBackground
            let onHoverColor: Color = .buttonMouseOver
            let onSelectedColor: Color = .buttonMouseDown
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
                    Image(.optionsMainView)
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
                .font(.system(size: 13))
            Divider()
            if includeContinueSetUpCards {
                HStack {
                    Toggle(isOn: $model.isContinueSetUpVisible, label: {
                        HStack {
                            Image(.rocketGrayscale)
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
                        Image(.favorite)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabFavoriteSectionTitle)
                    }
                })
                Spacer()
            }
            HStack {
                Toggle(isOn: $model.isRecentActivityVisible, label: {
                    HStack {
                        Image(.shield)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabRecentActivitySectionTitle)
                    }
                })
                Spacer()
            }
        }
    }
}
