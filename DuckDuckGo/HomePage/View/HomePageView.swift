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
import SwiftUIExtensions

extension HomePage.Views {

    struct RootView: View {

        static let targetWidth: CGFloat = 508
        static let minWindowWidth: CGFloat = 660
        static let settingsPanelWidth: CGFloat = 236
        static let customizeButtonPadding: CGFloat = 14
        let isBurner: Bool

        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel
        @EnvironmentObject var activeRemoteMessageModel: ActiveRemoteMessageModel
        @EnvironmentObject var settingsVisibilityModel: HomePage.Models.SettingsVisibilityModel
        @EnvironmentObject var addressBarModel: HomePage.Models.AddressBarModel
        @EnvironmentObject var recentlyVisitedModel: HomePage.Models.RecentlyVisitedModel

        @ObservedObject var freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator

        var body: some View {
            if isBurner {
                BurnerHomePageView()
            } else {
                regularHomePageView()
            }
        }

        enum Const {
            static let scrollViewCoordinateSpaceName = "scroll"
            static let searchBarIdentifier = "search bar"
            static let itemSpacing: CGFloat = 32
            static let remoteMessageTopPadding: CGFloat = 32
        }

        @State private var scrollPosition: CGFloat = 0
        @State private var remoteMessageHeight: CGFloat = 0

        var continueSetUpCardsTopPadding: CGFloat {
            addressBarModel.shouldShowAddressBar || activeRemoteMessageModel.shouldShowRemoteMessage ? 24 : 0
        }

        private func innerViewOffset(with geometry: GeometryProxy) -> CGFloat {
            max(0, ((Self.settingsPanelWidth + Self.minWindowWidth) - geometry.size.width) / 2)
        }

        func regularHomePageView() -> some View {
            GeometryReader { geometry in
                ZStack(alignment: .top) {

                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 0) {
                                        if shouldCenterContent(with: geometry) {
                                            innerViewCenteredVertically(geometry: geometry)
                                                .frame(width: geometry.size.width - (settingsVisibilityModel.isSettingsVisible ? Self.settingsPanelWidth : 0))
                                                .offset(x: settingsVisibilityModel.isSettingsVisible ? innerViewOffset(with: geometry) : 0)
                                                .fixedColorScheme(for: settingsModel.customBackground)
                                        } else {
                                            innerView(geometry: geometry)
                                                .frame(width: geometry.size.width - (settingsVisibilityModel.isSettingsVisible ? Self.settingsPanelWidth : 0))
                                                .offset(x: settingsVisibilityModel.isSettingsVisible ? innerViewOffset(with: geometry) : 0)
                                                .fixedColorScheme(for: settingsModel.customBackground)
                                        }
                                        scrollOffsetReader
                                    }
                                }
                                .animation(.none, value: recentlyVisitedModel.showRecentlyVisited)
                                .coordinateSpace(name: Const.scrollViewCoordinateSpaceName)
                                .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: hideSuggestionWindowIfScrolled)
                                .if(addressBarModel.shouldShowAddressBar) { view in
                                    view.onChange(of: addressBarModel.value) { _ in
                                        proxy.scrollTo(Const.searchBarIdentifier)
                                    }
                                }
                            }
                        }
                        .frame(width: settingsVisibilityModel.isSettingsVisible ? geometry.size.width - Self.settingsPanelWidth : geometry.size.width)
                        .contextMenu(menuItems: sectionsVisibilityContextMenuItems)

                        if settingsVisibilityModel.isSettingsVisible {
                            SettingsView(includingContinueSetUpCards: model.isContinueSetUpAvailable && !model.isContinueSetUpCardsViewOutdated && !model.continueSetUpCardsClosed,
                                         isSettingsVisible: $settingsVisibilityModel.isSettingsVisible)
                                .frame(width: Self.settingsPanelWidth)
                                .transition(.move(edge: .trailing))
                                .layoutPriority(1)
                                .environmentObject(settingsModel)
                        }
                    }
                    .animation(.easeInOut, value: settingsVisibilityModel.isSettingsVisible)

                    if !settingsVisibilityModel.isSettingsVisible {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer(minLength: Self.targetWidth + (geometry.size.width - Self.targetWidth)/2)
                                SettingsButtonView()
                                    .padding([.bottom, .trailing], 14)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
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

        func innerView(geometry: GeometryProxy) -> some View {
            VStack(spacing: Const.itemSpacing) {

                if !addressBarModel.shouldShowAddressBar || !activeRemoteMessageModel.shouldShowRemoteMessage {
                    Spacer(minLength: Const.itemSpacing)
                }

                Group {
                    remoteMessage()
                        .if(addressBarModel.shouldShowAddressBar) { view in
                            view.padding(.top, Const.remoteMessageTopPaddingWithSearchBar)
                        }

                    freemiumPromotionView()

                    if addressBarModel.shouldShowAddressBar {
                        BigSearchBox(isCompact: isCompactLogo(with: geometry))
                            .id(Const.searchBarIdentifier)
                            .visibility(model.isSearchBarVisible ? .visible : .gone)
                    }

                    if model.isContinueSetUpAvailable {
                        ContinueSetUpView()
                            .visibility(model.isContinueSetUpVisible ? .visible : .gone)
                            .padding(.top, continueSetUpCardsTopPadding)
                            .onAppear {
                                model.continueSetUpCardsViewDidAppear()
                            }
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
            if let remoteMessage = activeRemoteMessageModel.newTabPageRemoteMessage,
               let modelType = remoteMessage.content,
               modelType.isSupported {
                ZStack {
                    RemoteMessageView(viewModel: .init(
                        messageId: remoteMessage.id,
                        modelType: modelType,
                        onDidClose: { action in
                            await activeRemoteMessageModel.dismissRemoteMessage(with: action)
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
                    RemoteMessageHeightGetter()
                }
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

        @ViewBuilder
        func freemiumPromotionView() -> some View {
            if let viewModel = freemiumDBPPromotionViewCoordinator.viewModel {
                PromotionView(viewModel: viewModel)
                    .padding(.bottom, 16)
                    .visibility(freemiumDBPPromotionViewCoordinator.isHomePagePromotionVisible ? .visible : .gone)
            } else {
                EmptyView()
            }
        }

        @ViewBuilder
        func sectionsVisibilityContextMenuItems() -> some View {
            if addressBarModel.shouldShowAddressBar {
                Toggle(UserText.newTabMenuItemShowSearchBar, isOn: $model.isSearchBarVisible)
                    .toggleStyle(.checkbox)
            }
            if model.isContinueSetUpAvailable && !model.isContinueSetUpCardsViewOutdated && !model.continueSetUpCardsClosed {
                Toggle(UserText.newTabMenuItemShowContinuteSetUp, isOn: $model.isContinueSetUpVisible)
                    .toggleStyle(.checkbox)
                    .visibility(continueSetUpModel.hasContent ? .visible : .gone)
            }
            Toggle(UserText.newTabMenuItemShowFavorite, isOn: $model.isFavoriteVisible)
                .toggleStyle(.checkbox)
            Toggle(UserText.newTabMenuItemShowRecentActivity, isOn: $model.isRecentActivityVisible)
                .toggleStyle(.checkbox)
        }

        struct SettingsButtonView: View {
            static let defaultColor: Color = .homeFavoritesBackground
            static let onHoverColor: Color = .buttonMouseOver
            static let iconSize = 16.0
            static let height = 28.0
            static let buttonWidthWithoutTitle = 46.0

            @State var isHovering: Bool = false

            @State private var textWidth: CGFloat = .infinity {
                didSet {
                    settingsModel.settingsButtonWidth = textWidth + Self.buttonWidthWithoutTitle
                }
            }
            @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel
            @EnvironmentObject var settingsVisibilityModel: HomePage.Models.SettingsVisibilityModel

            private var buttonBackgroundColor: Color {
                isHovering ? Self.onHoverColor : Self.defaultColor
            }

            private func isCompact(with geometry: GeometryProxy) -> Bool {
                geometry.size.width < settingsModel.settingsButtonWidth
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
                                        .frame(width: Self.iconSize, height: Self.iconSize)
                                        .scaledToFit()
                                    if !isCompact(with: geometry) {
                                        Text(UserText.homePageSettingsTitle)
                                            .font(.system(size: 13))
                                            .background(WidthGetter())
                                    }
                                }
                                .frame(height: Self.height)
                                .padding(.horizontal, isCompact(with: geometry) ? 6 : 12)
                            }
                            .fixedSize()
                            .link(onHoverChanged: nil) {
                                withAnimation {
                                    settingsVisibilityModel.isSettingsVisible.toggle()
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

fileprivate extension HomePage.Views.RootView.Const {
    static let remoteMessageTopPaddingWithSearchBar: CGFloat = 16
}

/// This extension defines views and objects related to displaying Big Search Box.
fileprivate extension HomePage.Views.RootView {

    private typealias ContinueSetUpView = HomePage.Views.ContinueSetUpView
    private typealias Favorites = HomePage.Views.Favorites
    private typealias RecentlyVisited = HomePage.Views.RecentlyVisited

    func innerViewCenteredVertically(geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: Const.itemSpacing) {
                BigSearchBox(isCompact: isCompactLogo(with: geometry))
                    .id(Const.searchBarIdentifier)
                    .visibility(model.isSearchBarVisible ? .visible : .gone)

                if model.isContinueSetUpAvailable {
                    ContinueSetUpView()
                        .visibility(model.isContinueSetUpVisible ? .visible : .gone)
                        .padding(.top, continueSetUpCardsTopPadding)
                }

                Favorites()
                    .visibility(model.isFavoriteVisible ? .visible : .gone)

                RecentlyVisited()
                    .visibility(model.isRecentActivityVisible ? .visible : .gone)
            }
            .padding(.vertical, Const.itemSpacing)
            .frame(width: Self.targetWidth, height: totalHeight(with: geometry))
            .offset(y: -centeredViewVerticalOffset(with: geometry))

            VStack(spacing: 0) {
                remoteMessage()
                    .padding(.top, Const.remoteMessageTopPaddingWithSearchBar)
                Spacer()
                    .layoutPriority(1)
            }
            .frame(width: Self.targetWidth)
        }
        .frame(height: max(geometry.size.height, totalHeight(with: geometry)))
        .frame(maxWidth: .infinity)
        .onPreferenceChange(RemoteMessageHeightPreferenceKey.self) { value in
            remoteMessageHeight = value
        }
    }

    func centeredViewVerticalOffset(with geometry: GeometryProxy) -> CGFloat {
        0.1 * geometry.size.height
    }

    func shouldCenterContent(with geometry: GeometryProxy) -> Bool {
        guard addressBarModel.shouldShowAddressBar else {
            return false
        }
        if model.isContinueSetUpAvailable && model.isContinueSetUpVisible && continueSetUpModel.shouldShowAllFeatures {
            return false
        }
        if model.isFavoriteVisible && favoritesModel.showAllFavorites && favoritesModel.models.count > HomePage.favoritesPerRow {
            return false
        }
        if model.isRecentActivityVisible && recentlyVisitedModel.showRecentlyVisited {
            return false
        }
        let topSpacing: CGFloat = {
            if activeRemoteMessageModel.shouldShowRemoteMessage {
                return remoteMessageHeight + Const.remoteMessageTopPaddingWithSearchBar
            }
            return Const.remoteMessageTopPadding
        }()
        return geometry.size.height * 0.5 > (totalHeight(with: geometry) * 0.5 + topSpacing + centeredViewVerticalOffset(with: geometry))
    }

    func totalHeight(with geometry: GeometryProxy) -> CGFloat {
        let topAndBottomSpacers = Const.itemSpacing * 2
        var height = topAndBottomSpacers
        if model.isSearchBarVisible {
            height += isCompactLogo(with: geometry) ? BigSearchBox.Const.compactHeight : BigSearchBox.Const.totalHeight
        }
        if model.isContinueSetUpAvailable && model.isContinueSetUpVisible {
            height += continueSetUpModel.isMoreOrLessButtonNeeded ? 184 : 160
            height += Const.itemSpacing + continueSetUpCardsTopPadding
        }
        if model.isFavoriteVisible {
            height += 122 + Const.itemSpacing
        }
        if model.isRecentActivityVisible {
            height += 90 + Const.itemSpacing
        }
        return height
    }

    func isCompactLogo(with geometry: GeometryProxy) -> Bool {
        geometry.size.height < 650
    }

    @ViewBuilder
    var scrollOffsetReader: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named(Const.scrollViewCoordinateSpaceName)).minY
                )
        }
        .frame(height: 0)
    }

    /**
     * The suggestion window is not designed to follow the moving address bar,
     * so we're hiding it whenever the user scrolls the new tab page.
     */
    private func hideSuggestionWindowIfScrolled(_ value: CGFloat) {
        guard addressBarModel.shouldShowAddressBar, abs(scrollPosition - value) > 1 else {
            return
        }
        scrollPosition = value
        addressBarModel.hideSuggestionsWindow()
    }

    struct ScrollOffsetPreferenceKey: PreferenceKey {
        typealias Value = CGFloat
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    struct RemoteMessageHeightGetter: View {
        var body: some View {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: RemoteMessageHeightPreferenceKey.self, value: geometry.size.height)
            }
        }
    }

    struct RemoteMessageHeightPreferenceKey: PreferenceKey {
        typealias Value = CGFloat
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
