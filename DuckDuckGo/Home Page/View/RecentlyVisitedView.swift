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

    @State var isExpanded = true

    var body: some View {

        VStack {
            ProtectionSummary(isExpanded: $isExpanded)

            Group {
                if #available(macOS 11, *) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.recentSites, id: \.domain) {
                            RecentlyVisitedSite(site: $0)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.recentSites, id: \.domain) {
                            RecentlyVisitedSite(site: $0)
                        }
                    }
                }

                RecentlyVisitedSiteEmptyState()
                    .visibility(model.recentSites.isEmpty ? .visible : .gone)

            }
            .visibility(isExpanded ? .visible : .gone)

        }.padding(.bottom, 24)

    }

}

struct RecentlyVisitedSiteEmptyState: View {

    let textColor = Color("HomeFeedEmptyStateTextColor")
    let connectorColor = Color("HomeFeedItemVerticalConnectorColor")

    var body: some View {

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(connectorColor)
                Image("Web")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(textColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {

                Text("Recently visited sites appear here")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)

                Text("Keep browsing to see how many trackers were blocked")
                    .font(.system(size: 13))
                    .foregroundColor(textColor)

            }

            Spacer()

            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(connectorColor)
                    .frame(width: 24, height: 24)

                RoundedRectangle(cornerRadius: 8)
                    .fill(connectorColor)
                    .frame(width: 24, height: 24)
            }

        }.padding([.leading, .trailing], 12)

    }

}

struct RecentlyVisitedSite: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false
    @State var isBurning = false
    @State var isHidden = false

    var body: some View {
        ZStack(alignment: .top) {

            RoundedRectangle(cornerRadius: 8)
                .fill(Color("HomeFeedItemHoverBackgroundColor"))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
                .visibility(isHovering ? .visible : .gone)

            HStack {

                SiteIcon(site: site)

                VStack(alignment: .leading, spacing: 12) {

                    HyperLink(site.domain) {
                        guard let url = site.domain.url else { return }
                        model.open(url)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundColor(Color("HomeFeedItemTitleColor"))

                    SiteTrackerSummary(site: site)
                        .visibility(site.numberOfTrackersBlocked > 0 ? .visible : .gone)

                    RecentlyVisitedPageList(site: site)
                        .visibility(!model.showPagesOnHover || isHovering ? .visible : .invisible)

                }
                .padding([.leading, .bottom], 12)

                Spacer()

            }
            .padding([.leading, .trailing, .top], 12)
            .visibility(isHidden ? .invisible : .visible)

            HStack(spacing: 2) {

                Spacer()

                HoverButton(size: 24, imageName: site.isFavorite ? "FavoriteFilled" : "Favorite", imageSize: 16) {
                    model.toggleFavoriteSite(site)
                }
                .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                .tooltip(UserText.tooltipAddToFavorites)

                HoverButton(size: 24, imageName: "Burn", imageSize: 16) {
                    isHovering = false
                    isBurning = true
                    withAnimation(.default.delay(0.4)) {
                        isHidden = true
                    }
                }
                .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                .tooltip(UserText.tooltipBurn)

            }
            .padding([.top, .trailing], 12)
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

struct RecentlyVisitedPageList: View {

    let collapsedPageCount = 2

    let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    } ()

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isExpanded = false

    var visiblePages: [HomePage.Models.RecentlyVisitedPageModel] {
        isExpanded ? site.pages : [HomePage.Models.RecentlyVisitedPageModel](site.pages.prefix(collapsedPageCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(visiblePages, id: \.url) { page in
                HStack {

                    HyperLink(page.displayTitle) {
                        model.open(page.url)    
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color("HomeFeedItemPageTextColor"))

                    Text(formatter.localizedString(fromTimeInterval: page.visited.timeIntervalSinceNow))
                        .font(.system(size: 11))
                        .foregroundColor(Color("HomeFeedItemTimeTextColor"))

                    HoverButton(size: 16, imageName: "HomeArrowDown", imageSize: 8) {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .visibility(page.url == visiblePages.last?.url &&
                                site.pages.count > collapsedPageCount ? .visible : .gone)

                    Spacer()
                }.frame(maxHeight: 13)

            }
        }
    }

}

struct SiteIcon: View {

    var site: HomePage.Models.RecentlyVisitedSiteModel

    var body: some View {
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
    }

}

struct SiteTrackerSummary: View {

    let trackerIconCount = 2

    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    var body: some View {
        HStack(spacing: 0) {

            // Top 3 entities
            HStack(spacing: 2) {
                ForEach(site.blockedEntities.prefix(trackerIconCount), id: \.self) {
                    EntityIcon(imageName: site.entityImageName($0), displayName: site.entityDisplayName($0))
                }

                // Count of other entities, if any
                let remainingCount = site.blockedEntities.count - trackerIconCount
                if remainingCount > 9 {
                    SmallCircleText(text: "++")
                        .tooltip("+\(remainingCount)")
                } else if remainingCount > 0 {
                    SmallCircleText(text: "+\(remainingCount)")
                }
            }
            .padding(.trailing, 6)

            // Text summary
            Text(UserText.pageTrackersMessage(numberOfTrackersBlocked: site.numberOfTrackersBlocked))
                .font(.system(size: 13))

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
