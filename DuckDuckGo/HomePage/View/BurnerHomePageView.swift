//
//  BurnerHomePageView.swift
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
import SwiftUI

extension HomePage.Views {

    struct BurnerHomePageView: View {

        static let height: CGFloat = 273

        enum Const {
            static let verticalPadding = 40.0
            static let searchBoxVerticalSpacing = 24.0
        }

        var totalHeight: CGFloat {

            var totalHeight = Self.height + 2 * Const.verticalPadding

            if addressBarModel.shouldShowAddressBar && model.isSearchBarVisible {
                totalHeight += Const.searchBoxVerticalSpacing + BigSearchBox.Const.totalHeight
            }
            return totalHeight
        }

        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var addressBarModel: HomePage.Models.AddressBarModel

        let backgroundColor = Color(.newTabPageBackground)
        private var infoBackgroundColor: Color {
            return colorScheme == .dark ? Color.white.opacity(0.03) : backgroundColor
        }

        private var infoStrokeColor1: Color {
            return colorScheme == .dark ? Color.white.opacity(0.03) : Color.clear
        }

        private var infoStrokeColor2: Color {
            return colorScheme == .dark ? Color.black.opacity(0.12) : Color.gray.opacity(0.09)
        }

        private var infoShadowColor: Color {
            return colorScheme == .dark ? Color.black.opacity(0.12) : Color.black.opacity(0.05)
        }

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    ScrollView {
                        VStack(spacing: Const.searchBoxVerticalSpacing) {
                            Spacer(minLength: Const.verticalPadding)

                            Group {
                                if addressBarModel.shouldShowAddressBar {
                                    BigSearchBox(isCompact: false, supportsFixedColorScheme: false)
                                        .visibility(model.isSearchBarVisible ? .visible : .gone)
                                }

                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                                        .homePageViewBackground(nil)
                                        .cornerRadius(12)

                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Image(.burnerWindowHomepage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 64, height: 48)
                                                .padding(.leading, -15)
                                                .padding(.top, -5)

                                            Text(UserText.burnerWindowHeader)
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(Color.primary)
                                                .padding(.leading, -10)
                                        }

                                        FeaturesBox()
                                            .padding(.top, 10)
                                    }
                                    .padding(.horizontal, 40)
                                }
                                .frame(height: Self.height)
                            }
                            .frame(width: HomePage.Views.RootView.targetWidth)

                            Spacer(minLength: Const.verticalPadding)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: max(geometry.size.height, totalHeight))
                    }
                }
                .background(backgroundColor)
            }
        }
    }

    struct FeaturesBox: View {

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(.burnerWindowIcon1)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription1)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)

                    }

                    HStack {
                        Image(.burnerWindowIcon2)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription2)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }

                    HStack {
                        Image(.burnerWindowIcon3)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription3)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }

                    Divider()

                    HStack {
                        Image(.burnerWindowIcon4)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                            .opacity(0.6)
                            .padding(.top, -20)
                        Text(UserText.burnerHomepageDescription4)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }
                }
            }
        }
}
