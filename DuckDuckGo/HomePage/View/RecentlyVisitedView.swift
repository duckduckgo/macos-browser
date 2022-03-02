//
//  RecentlyVisitedView.swift
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

extension HomePage.Views {

struct RecentlyVisited: View {

    let dateFormatter = RelativeDateTimeFormatter()

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    var body: some View {

        VStack {
            ProtectionSummary()

            if #available(macOS 11, *) {
                LazyVStack {
                    ForEach(model.recentSites, id: \.domain) {
                        RecentlyVisitedSite(site: $0)
                    }
                }
            } else {
                VStack {
                    ForEach(model.recentSites, id: \.domain) {
                        RecentlyVisitedSite(site: $0)
                    }
                }
            }
            
        }.padding(.bottom, 24)

    }

}

struct RecentlyVisitedSite: View {

    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false

    var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: 8)
                .fill(Color("HomePageBackgroundColor"))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
                .visibility(isHovering ? .visible : .gone)

            HStack(alignment: .top) {

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .frame(width: 32, height: 32)

                    Rectangle()
                        .fill(.gray)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                VStack(alignment: .leading) {

                    HStack {
                        Text(site.domain)
                            .font(.system(size: 15, weight: .bold, design: .default))

                        Spacer()

                        HoverButton(imageName: "Favorite") {
                        }
                        .tooltip("Add to Favorites")

                        HoverButton(imageName: "Burn") {
                        }
                        .tooltip("Burn History and Site data")

                    }

                    Text("Some trackers were blocked")
                        .font(.system(size: 13))

                }.padding(.bottom, 12)

                Spacer()

            }.padding([.leading, .trailing, .top], 12)

        }
        .onHover {
            isHovering = $0
        }
        .frame(maxWidth: .infinity)

    }

}

}

extension View {

    @ViewBuilder func tooltip(_ message: String) -> some View {
        if #available(macOS 11, *) {
            self.help(message)
        } else {
            self
        }
    }

}
