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

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false
    @State var isBurning = false
    @State var isHidden = false

    var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: 8)
                .fill(Color("HomePageBackgroundColor"))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
                .visibility(isHovering ? .visible : .gone)

            HStack(alignment: .top) {

                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color("HomeFeedItemVerticalConnectorColor"))

                        FaviconView(domain: site.domain, size: 22)

                    }
                    .frame(width: 32, height: 32)

                    Rectangle()
                        .fill(Color("HomeFeedItemVerticalConnectorColor"))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                VStack(alignment: .leading) {

                    HStack {
                        Text(site.domain)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(Color("HomeFeedItemTitleColor"))

                        Spacer()

                        HoverButton(imageName: site.isFavorite ? "FavoriteFilled" : "Favorite") {
                            model.toggleFavoriteSite(site)
                        }
                        .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                        .tooltip("Add to Favorites")

                        HoverButton(imageName: "Burn") {
                            isHovering = false
                            isBurning = true
                            withAnimation(.default.delay(0.4)) {
                                isHidden = true
                            }
                        }
                        .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                        .tooltip("Burn History and Site data")

                    }

                    if site.numberOfTrackersBlocked > 0 {
                        SiteTrackerSummary(site: site)
                    }

                }.padding(.bottom, 12)

                Spacer()

            }
            .padding([.leading, .trailing, .top], 12)
            .visibility(isHidden ? .invisible : .visible)

            FireAnimation()
                .cornerRadius(8)
                .visibility(isBurning ? .visible : .gone)
                .zIndex(100)
                .onAppear {
                    withAnimation(.default.delay(1.0)) {
                        isBurning = false
                    }
                }
                .onDisappear {
                    withAnimation {
                        model.burn(site)
                    }
                }

        }
        .onHover {
            isHovering = $0
        }
        .frame(maxWidth: .infinity)

    }

}

struct SiteTrackerSummary: View {

    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    var body: some View {
        HStack {

            // Top 3 entities
            HStack(spacing: 2) {
                ForEach(site.blockedEntities.prefix(3), id: \.self) {
                    EntityIcon(imageName: site.entityImageName($0), displayName: site.entityDisplayName($0))
                }

                // Count of other entities, if any
                let remainingCount = site.blockedEntities.count - 3
                if remainingCount > 9 {
                    SmallCircleText(text: "++")
                        .tooltip("+\(remainingCount)")
                } else if remainingCount > 0 {
                    SmallCircleText(text: "+\(remainingCount)")
                }
            }

            // Text summary
            if #available(macOS 11, *) {
                Text("**\(site.numberOfTrackersBlocked)** Tracking Attempts Blocked")
                    .font(.system(size: 13))
            } else {
                Text("\(site.numberOfTrackersBlocked)")
                    .font(.system(size: 13))
                    .fontWeight(.bold)
                Text(" Tracking Attempts Blocked")
                    .font(.system(size: 13))
            }

            Spacer()
        }
    }

}

struct EntityIcon: View {

    let size: CGFloat = 18

    var imageName: String
    var displayName: String

    var body: some View {

        Group {

            if let image = NSImage(named: "feed-" + imageName) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .tooltip(displayName)

            } else {

                SmallCircleText(text: String(displayName.first ?? "?"))
                    .tooltip(displayName)

            }

        }.frame(width: size, height: size, alignment: .center)

    }

}

struct SmallCircleText: View {

    let text: String
    let backgroundColor: Color
    let textColor: Color

    init(text: String, backgroundColor: Color = Color("HomeEntityIconBackgroundColor"), textColor: Color = Color("HomeEntityIconTextColor")) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    var body: some View {
        ZStack {

            Circle()
                .foregroundColor(backgroundColor)

            Text(String(text))
                .foregroundColor(textColor)
                .font(.system(size: 10, weight: .bold, design: .default))

        }.frame(width: 18, height: 18, alignment: .center)
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
