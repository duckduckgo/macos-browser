//
//  DisposableHomePageView.swift
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

    struct DisposableHomePageView: View {

        @Environment(\.colorScheme) var colorScheme

        private var backgroundColor: Color {
            return colorScheme == .dark ? Color.black.opacity(0.15) : Color.white
        }

        var body: some View {
            ZStack {
                Image("BurnerWindowBackground")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image("BurnerWindowPopoverImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 48)
                            .padding(.leading, -15)

                        Text("Burner Window")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.primary)
                            .padding(.leading, -10)
                            .padding(.top, 15)
                    }

                    Description()
                        .padding(.top, 3)

                    FeaturesBox()
                        .padding(.top, 10)
                }
                .frame(width: 480, height: 260, alignment: .center)
                .padding()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            }
        }
    }

    struct Description: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                Text("All" + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.primary)
                + Text("DuckDuckGo windows block most hidden trackers so websites can't spy on you.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.primary)

                Text("Burner windows" + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.primary)
                + Text("are temporary: they don't access existing cookies or remember websites you visit after you close the window.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.primary)
            }
        }
    }

    struct FeaturesBox: View {

            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Burner Windows make it easier to:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.primary)

                    HStack {
                        Image("BurnerWindowPopoverIcon1")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("Sign into a site with a different account")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)

                    }

                    HStack {
                        Image("BurnerWindowPopoverIcon2")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        Text("View websites without signing in")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }
                }
            }
        }
}
