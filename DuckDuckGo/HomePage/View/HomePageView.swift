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
        let settingsPanelWidth: CGFloat = 236
        let isBurner: Bool

        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel
        @EnvironmentObject var activeRemoteMessageModel: ActiveRemoteMessageModel

        @State private var isSettingsVisible = false

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

        func innerViewOffset(with geometry: GeometryProxy) -> CGFloat {
            max(0, ((settingsPanelWidth + 600) - geometry.size.width) / 2)
        }

        func regularHomePageView(includingContinueSetUpCards: Bool) -> some View {
            GeometryReader { geometry in
                ZStack(alignment: .top) {

                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            ScrollView {
                                innerView(includingContinueSetUpCards: includingContinueSetUpCards)
                                    .frame(width: geometry.size.width - (isSettingsVisible ? settingsPanelWidth : 0))
                                    .offset(x: isSettingsVisible ? innerViewOffset(with: geometry) : 0)
                                    .ifLet(settingsModel.customBackground?.colorScheme) { view, colorScheme in
                                        view.colorScheme(colorScheme)
                                    }
                            }
                        }
                        .frame(width: isSettingsVisible ? geometry.size.width - settingsPanelWidth : geometry.size.width)

                        if isSettingsVisible {
                            SettingsView(includingContinueSetUpCards: includingContinueSetUpCards, isSettingsVisible: $isSettingsVisible)
                                .frame(width: settingsPanelWidth)
                                .transition(.move(edge: .trailing))
                                .layoutPriority(1)
                                .environmentObject(settingsModel)
                        }
                    }
                    .animation(.easeInOut, value: isSettingsVisible)

                    if !isSettingsVisible {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer(minLength: Self.targetWidth + (geometry.size.width - Self.targetWidth)/2)
                                SettingsButtonView(isSettingsVisible: $isSettingsVisible)
                                    .padding(.bottom, 14)
                                    .padding(.trailing, 14)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ifLet(settingsModel.customBackground?.colorScheme) { view, colorScheme in
                            view.colorScheme(colorScheme)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    backgroundView
                        .animation(.none, value: isSettingsVisible)
                        .animation(.easeInOut(duration: 0.5), value: settingsModel.customBackground)
                )
                .clipped()
                .onAppear {
                    LocalBookmarkManager.shared.requestSync()
                }
            }
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
                gradient.image.resizable().aspectRatio(contentMode: .fill)
                    .animation(.none, value: settingsModel.contentType)
            case .illustration(let illustration):
                illustration.image.resizable().aspectRatio(contentMode: .fill)
                    .animation(.none, value: settingsModel.contentType)
            case .solidColor(let solidColor):
                solidColor.color
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

            @State var isHovering: Bool = false
            @Binding var isSettingsVisible: Bool

            @State private var textWidth: CGFloat = .infinity
            @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

            private var buttonBackgroundColor: Color {
                isHovering ? onHoverColor : defaultColor
            }

            private func isCompact(with geometry: GeometryProxy) -> Bool {
                geometry.size.width < textWidth + 52
            }

            var body: some View {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer(minLength: 0)
                            ZStack(alignment: .bottomTrailing) {
                                if let customBackground = settingsModel.customBackground {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                                        .homePageViewBackground(customBackground)
                                        .cornerRadius(6)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                                        .background(Color.homeFavoritesBackground)
                                        .cornerRadius(6)
                                }

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(buttonBackgroundColor)

                                HStack(spacing: 6) {
                                    Image(.optionsMainView)
                                        .resizable()
                                        .frame(width: iconSize, height: iconSize)
                                        .scaledToFit()
                                    if !isCompact(with: geometry) {
                                        Text("Customize")
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
