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

        static let targetWidth: CGFloat = 508
        static let minWindowWidth: CGFloat = 600
        static let settingsPanelWidth: CGFloat = 236
        let isBurner: Bool

        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel
        @EnvironmentObject var activeRemoteMessageModel: ActiveRemoteMessageModel
        @EnvironmentObject var settingsVisibilityModel: HomePage.Models.SettingsVisibilityModel

        var body: some View {
            if isBurner {
                BurnerHomePageView()
            } else {
                regularHomePageView(includingContinueSetUpCards: model.isContinueSetUpAvailable)
            }
        }

        func regularHomePageView(includingContinueSetUpCards: Bool) -> some View {
            GeometryReader { geometry in
                ZStack(alignment: .top) {

                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            ScrollView {
                                innerView(includingContinueSetUpCards: includingContinueSetUpCards)
                                    .frame(width: geometry.size.width - (settingsVisibilityModel.isSettingsVisible ? Self.settingsPanelWidth : 0))
                                    .offset(x: settingsVisibilityModel.isSettingsVisible ? innerViewOffset(with: geometry) : 0)
                                    .fixedColorScheme(for: settingsModel.customBackground)
                            }
                        }
                        .frame(width: settingsVisibilityModel.isSettingsVisible ? geometry.size.width - Self.settingsPanelWidth : geometry.size.width)
                        .contextMenu(ContextMenu {
                            if model.isContinueSetUpAvailable {
                                Toggle(UserText.newTabMenuItemShowContinuteSetUp, isOn: $model.isContinueSetUpVisible)
                                    .toggleStyle(.checkbox)
                                    .visibility(continueSetUpModel.hasContent ? .visible : .gone)
                            }
                            Toggle(UserText.newTabMenuItemShowFavorite, isOn: $model.isFavoriteVisible)
                                .toggleStyle(.checkbox)
                            Toggle(UserText.newTabMenuItemShowRecentActivity, isOn: $model.isRecentActivityVisible)
                                .toggleStyle(.checkbox)
                        })

                        if settingsVisibilityModel.isSettingsVisible {
                            SettingsView(includingContinueSetUpCards: includingContinueSetUpCards, isSettingsVisible: $settingsVisibilityModel.isSettingsVisible)
                                .frame(width: Self.settingsPanelWidth)
                                .transition(.move(edge: .trailing))
                                .layoutPriority(1)
                                .environmentObject(settingsModel)
                        }
                    }
                    .animation(.easeInOut, value: settingsVisibilityModel.isSettingsVisible)

                    if !settingsVisibilityModel.isSettingsVisible {
                        SettingsButtonView(isSettingsVisible: $settingsVisibilityModel.isSettingsVisible)
                            .padding([.bottom, .trailing], 14)
                            .fixedColorScheme(for: settingsModel.customBackground)
                    }
                }
                .background(
                    backgroundView
                        .animation(.none, value: settingsVisibilityModel.isSettingsVisible)
                        .animation(.easeInOut(duration: 0.5), value: settingsModel.customBackground)
                )
                .clipped()
                .onAppear {
                    LocalBookmarkManager.shared.requestSync()
                }
            }
        }

        private func innerViewOffset(with geometry: GeometryProxy) -> CGFloat {
            max(0, ((Self.settingsPanelWidth + Self.minWindowWidth) - geometry.size.width) / 2)
        }

        func innerView(includingContinueSetUpCards: Bool) -> some View {
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

        @ViewBuilder
        var backgroundView: some View {
            switch settingsModel.customBackground {
            case .gradient(let gradient):
                gradient.view
                    .animation(.none, value: settingsModel.contentType)
            case .solidColor(let solidColor):
                Color(hex: solidColor.color.hex())
                    .animation(.none, value: settingsModel.contentType)
            case .userImage(let userBackgroundImage):
                if let nsImage = settingsModel.customImagesManager?.image(for: userBackgroundImage) {
                    Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill)
                        .animation(.none, value: settingsModel.contentType)
                } else {
                    Color.newTabPageBackground
                }
            case .none:
                Color.newTabPageBackground
            }
        }

        struct SettingsButtonView: View {
            let defaultColor: Color = .homeFavoritesBackground
            let onHoverColor: Color = .buttonMouseOver
            let onSelectedColor: Color = .buttonMouseDown
            let iconSize = 16.02
            let targetSize = 28.0
            let buttonWidthWithoutTitle = 52.0

            @State var isHovering: Bool = false
            @Binding var isSettingsVisible: Bool

            @State private var textWidth: CGFloat = .infinity
            @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

            private var buttonBackgroundColor: Color {
                isHovering ? onHoverColor : defaultColor
            }

            private func isCompact(with geometry: GeometryProxy) -> Bool {
                geometry.size.width < textWidth + buttonWidthWithoutTitle
            }

            var body: some View {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer(minLength: 0)
                            ZStack(alignment: .bottomTrailing) {

                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                                    .homePageViewBackground(settingsModel.customBackground)
                                    .cornerRadius(6)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(buttonBackgroundColor)

                                HStack(spacing: 6) {
                                    Image(.optionsMainView)
                                        .resizable()
                                        .frame(width: iconSize, height: iconSize)
                                        .scaledToFit()
                                    if !isCompact(with: geometry) {
                                        Text(UserText.homePageSettingsTitle)
                                            .font(.system(size: 13))
                                            .background(WidthGetter())
                                    }
                                }
                                .frame(height: targetSize)
                                .padding(.horizontal, isCompact(with: geometry) ? 6 : 12)
                            }
                            .fixedSize()
                            .link(onHoverChanged: nil) {
                                withAnimation {
                                    isSettingsVisible.toggle()
                                }
                            }
                            .onHover { isHovering in
                                self.isHovering = isHovering
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .onPreferenceChange(WidthPreferenceKey.self) { width in
                    self.textWidth = width
                }
            }
        }

        /**
         * This view updates a custom preference key with its width.
         *
         * The view is used as the background for the button's title, so that it can report the text width.
         * The button view listens to changes of the preference key and updates its state variable accordingly
         * to decide on the mode (compact or full-size) of the button.
         */
        struct WidthGetter: View {
            var body: some View {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
                }
            }
        }

        struct WidthPreferenceKey: PreferenceKey {
            typealias Value = CGFloat
            static var defaultValue: CGFloat = 0

            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = nextValue()
            }
        }
    }
}
