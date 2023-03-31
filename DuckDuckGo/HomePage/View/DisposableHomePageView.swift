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
                LinearGradient(gradient: Gradient(colors: [Color.white, Color(hex: "FFA235").opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Image("DisposableWindowIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 96)

                    Text("Burner Window")
                        .padding(.top, 30)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.primary)

                    Description()
                        .padding(.top, -40)

                    FeaturesBox()
                        .padding(.top, -20)
                }
                .frame(width: 600, height: 600, alignment: .center)
            }
        }
    }

    struct Description: View {
        var body: some View {
            VStack(spacing: 5) {
                Text("All of your windows are private by default, with:")
                    .font(.system(size: 15))
                    .foregroundColor(Color.primary)
                BoldPhrases()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .cornerRadius(20)
            .padding(.vertical, 40)
        }
    }

    struct BoldPhrases: View {
        var body: some View {
            Text("Private Search")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.primary)
                + Text(", ")
                    .font(.system(size: 15))
                    .foregroundColor(Color.primary)
                + Text("Web Tracking Protection")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.primary)
                + Text(", and ")
                    .font(.system(size: 15))
                    .foregroundColor(Color.primary)
                + Text("Smarter Encryption.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.primary)
        }
    }

    struct FeaturesBox: View {
            var body: some View {
                VStack(alignment: .leading, spacing: 15) {
                    Text("In addition ")
                        .font(.system(size: 15))
                        .foregroundColor(Color.primary)
                    + Text("Burner Windows")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.primary)
                    + Text(" also:")
                        .font(.system(size: 15))
                        .foregroundColor(Color.primary)

                    HStack {
                        Image("BurnerWindowPopoverIcon1")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("Won't remember the pages you visit")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }.padding(.top, 10)

                    HStack {
                        Image("BurnerWindowPopoverIcon2")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("Are separate from your regular browsing session")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }

                    HStack {
                        Image("BurnerWindowPopoverIcon3")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("Clears your website data when closed")
                            .font(.system(size: 13))
                            .foregroundColor(Color.primary)
                    }
                }
                .padding()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            }
        }

}
