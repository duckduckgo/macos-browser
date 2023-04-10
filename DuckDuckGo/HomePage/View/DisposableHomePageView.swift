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

        var body: some View {
            ZStack {
                Image("BurnerWindowBackground")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    HStack {
                        Image("BurnerWindowPopoverImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 48)

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
                .frame(width: 600, height: 600, alignment: .center)
                .padding(.top, -50)
            }
        }
    }

    struct Description: View {
        var body: some View {
            Text("Unlike other browsers, ")
                .font(.system(size: 15))
                .foregroundColor(Color.primary)
            + Text("all")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.primary)
            + Text(" DuckDuckGo windows are private.")
                .font(.system(size: 15))
                .foregroundColor(Color.primary)
        }
    }

    struct FeaturesBox: View {

            @Environment(\.colorScheme) var colorScheme

            private var backgroundColor: Color {
                return colorScheme == .dark ? Color.black.opacity(0.15) : Color.white
            }

            var body: some View {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Burner Windows make it easier to:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.primary)
                        .padding(.top, -10)

                    HStack {
                        Image("BurnerWindowPopoverIcon1")
                            .resizable()
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading) {
                            Text("Sign into a site with a different account.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.primary)
                            Text("For example a work or personal account.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.secondary)
                        }

                    }

                    HStack {
                        Image("BurnerWindowPopoverIcon2")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.primary)
                        VStack(alignment: .leading) {
                            Text("Quickly visit a site in a signed-out state.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.primary)
                            Text("For example to avoid seeing recommendations.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.secondary)
                        }
                    }

                    Divider()
                        .frame(width: 316)

                    Text("Burner Windows automatically burn data on close.\nHistory and cookies are always isolated just to the\nBurner Window.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.primary)

                    HStack {
                        Text("You can always burn data using the Fire Button.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                        Image("BurnerWindowHomepageFireIcon")
                    }

                }
                .padding()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            }
        }

}
