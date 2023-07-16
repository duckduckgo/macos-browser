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

        @Environment(\.colorScheme) var colorScheme

        let backgroundColor = Color("NewTabPageBackgroundColor")
        private var infoBackgroundColor: Color {
            return colorScheme == .dark ? Color.white.opacity(0.03) : backgroundColor
        }

        private var infoStrokeColor: Color {
            return colorScheme == .dark ? Color.white.opacity(0.03) : Color.gray.opacity(0.09)
        }

        private var infoShadowColor: Color {
            return colorScheme == .dark ? Color.black.opacity(0.12) : Color.black.opacity(0.05)
        }

        var body: some View {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image("BurnerWindowHomepageImage")
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
                .frame(width: HomePage.Views.RootView.targetWidth,
                       height: Self.height,
                       alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 8).fill(infoBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(infoStrokeColor, lineWidth: 1))
                .shadow(color: infoShadowColor, radius: 2, x: 0, y: 2)
            }
        }
    }

    struct FeaturesBox: View {

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image("FireWindowIcon1")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription1)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)

                    }

                    HStack {
                        Image("FireWindowIcon2")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription2)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }

                    HStack {
                        Image("FireWindowIcon3")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text(UserText.burnerHomepageDescription3)
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }

                    Divider()

                    HStack {
                        Image("FireWindowIcon4")
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
