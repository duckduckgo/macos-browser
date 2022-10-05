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

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    @State var isExpanded = true

    var body: some View {

        VStack(spacing: 0) {
            RecentlyVisitedTitle(isExpanded: $isExpanded)
                .padding(.bottom, 18)

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
    let iconColor = Color("HomeFeedEmptyStateIconColor")
    let connectorColor = Color("HomeFavoritesBackgroundColor")

    var body: some View {

        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(connectorColor)
                Image("Web")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(iconColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {

                Text(UserText.homePageEmptyStateItemTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)

                Text(UserText.homePageEmptyStateItemMessage)
                    .font(.system(size: 13))
                    .foregroundColor(textColor)

            }.padding(.top, 6)

            Spacer()

        }.padding([.leading, .trailing], 12)

    }

}

struct RecentlyVisitedSite: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false
    @State var showsAlert = false

    var body: some View {
        ZStack(alignment: .top) {

            RoundedRectangle(cornerRadius: 8)
                .fill(Color("HomeFeedItemHoverBackgroundColor"))
                .shadow(color: Color("HomeFeedItemHoverShadow1Color"), radius: 4, x: 0, y: 4)
                .shadow(color: Color("HomeFeedItemHoverShadow2Color"), radius: 2, x: 0, y: 1)
                .visibility(isHovering && model.showPagesOnHover ? .visible : .gone)

            HStack(alignment: .top, spacing: 12) {

                SiteIconAndConnector(site: site)

                VStack(alignment: .leading, spacing: 6) {

                    if site.isRealDomain {
                        HyperLink(site.domain, textColor: Color("HomeFeedItemTitleColor")) {
                            model.open(site)
                        }
                        .font(.system(size: 15, weight: .semibold, design: .default))
                    } else {
                        Text(site.domain)
                            .foregroundColor(Color("HomeFeedItemTitleColor"))
                            .font(.system(size: 15, weight: .semibold, design: .default))
                    }

                    SiteTrackerSummary(site: site)
                        .padding(.bottom, 6)

                    RecentlyVisitedPageList(site: site)
                        .visibility(!model.showPagesOnHover || isHovering ? .visible : .invisible)

                }
                .padding(.bottom, 12)
                .padding(.top, 6)

                Spacer()

            }
            .padding([.leading, .trailing, .top], 12)
            .visibility(site.isHidden ? .invisible : .visible)

            HStack(spacing: 2) {

                Spacer()

                HoverButton(size: 24, imageName: site.isFavorite ? "FavoriteFilled" : "Favorite", imageSize: 16, cornerRadius: 4) {
                    model.toggleFavoriteSite(site)
                }
                .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                .tooltip(UserText.tooltipAddToFavorites)

                HoverButton(size: 24, imageName: "Burn", imageSize: 16, cornerRadius: 4) {
                    isHovering = false
                    if site.isFireproof {
                        showsAlert = true
                    } else {
                        burn()
                    }
                }
                .alert(isPresented: $showsAlert) {
                    Alert(title: Text(UserText.homePageBurnFireproofSiteAlert),
                          primaryButton: .destructive(Text(UserText.homePageClearHistory), action: burn),
                          secondaryButton: .cancel(Text(UserText.cancel)))
                }
                .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                .tooltip(fireButtonTooltip)

            }
            .padding(.trailing, 12)
            .padding(.top, 13)
            .visibility(site.isHidden ? .invisible : .visible)

            FireAnimation()
                .cornerRadius(8)
                .visibility(site.isBurning ? .visible : .gone)
                .zIndex(100)
                .onAppear {
                    withAnimation(.default.delay(1.0)) {
                        site.isBurning = false
                    }
                }
                .onDisappear {
                    withAnimation {
                        model.burn(site)
                    }
                }

        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .frame(maxWidth: .infinity, minHeight: model.showPagesOnHover ? 126 : 0)
        .padding(.bottom, model.showPagesOnHover ? 0 : 12)

    }

    private var fireButtonTooltip: String {
        if site.isFireproof {
            return UserText.tooltipClearHistory(domain: site.domain)
        }
        return UserText.tooltipClearHistoryAndData(domain: site.domain)
    }

    private func burn() {
        site.isBurning = true
        withAnimation(.default.delay(0.4)) {
            site.isHidden = true
        }
    }

}

struct RecentlyVisitedPageList: View {

    let collapsedPageCount = 2

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isExpanded = false

    var visiblePages: [HomePage.Models.RecentlyVisitedPageModel] {
        isExpanded ? site.pages : [HomePage.Models.RecentlyVisitedPageModel](site.pages.prefix(collapsedPageCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visiblePages, id: \.url) { page in
                RecentlyVisitedPage(page: page,
                                    showExpandButton: page.url == visiblePages.last?.url && site.pages.count > collapsedPageCount,
                                    isExpanded: $isExpanded)
            }
        }
    }

}

struct RecentlyVisitedPage: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    let linkColor = Color("LinkBlueColor")
    let pageTextColor = Color("HomeFeedItemPageTextColor")
    let timeTextColor = Color("HomeFeedItemTimeTextColor")

    let page: HomePage.Models.RecentlyVisitedPageModel
    let showExpandButton: Bool
    @Binding var isExpanded: Bool

    @State var isHovering = false

    var body: some View {
        HStack {
            HStack {
                Text(page.displayTitle)
                    .optionalUnderline(isHovering)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(isHovering ? linkColor : pageTextColor)

                Text(model.relativeTime(page.visited))
                    .font(.system(size: 12))
                    .foregroundColor(timeTextColor)
            }
            .frame(height: 21)
            .link { isHovering in
                self.isHovering = isHovering

                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pointingHand.pop()
                }

            } clicked: {
                model.open(page.url)
            }

            HoverButton(size: 16, imageName: "HomeArrowDown", imageSize: 8, cornerRadius: 4) {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .visibility(
                showExpandButton ? .visible : .invisible
            )

            Spacer()
        }

    }

}

struct RecentlyVisitedTitle: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    @Binding var isExpanded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("HomeShield")
                .resizable()
                .frame(width: 22, height: 22)
                .onTapGesture(count: 2) {
                    model.showPagesOnHover.toggle()
                }
                .padding(.leading, isExpanded ? 5 : 0)

            VStack(alignment: isExpanded ? .leading : .center, spacing: 6) {
                Text(UserText.homePageProtectionSummaryMessage(numberOfTrackersBlocked: model.numberOfTrackersBlocked))
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(Color("HomeFeedTitleColor"))

                Text(UserText.homePageProtectionDurationInfo)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color("HomeFeedItemTimeTextColor"))
            }
            .visibility(model.recentSites.count > 0 ? .visible : .gone)
            .padding(.leading, 4)
            .padding(.top, 4)

            Text(UserText.homePageProtectionSummaryInfo)
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(Color("HomeFeedTitleColor"))
                .visibility(model.recentSites.count > 0 ? .gone : .visible)

            Spacer()
                .visibility(isExpanded ? .visible : .gone)

            HoverButton(size: 24, imageName: "HomeArrowUp", imageSize: 16, cornerRadius: 4) {
                withAnimation {
                    isExpanded.toggle()
                }
            }.rotationEffect(.degrees(isExpanded ? 0 : 180))

        }
        .padding([.leading, .trailing], 12)
    }

}

struct SiteIconAndConnector: View {

    let backgroundColor = Color("HomeFavoritesBackgroundColor")
    let mouseOverColor: Color = Color("HomeFavoritesHoverColor")

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? mouseOverColor : backgroundColor)

                FaviconView(domain: site.domain, size: 22)
            }
            .link {
                self.isHovering = $0

                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pointingHand.pop()
                }
                
            } clicked: {
                model.open(site)
            }
            .frame(width: 32, height: 32)

            Rectangle()
                .fill(backgroundColor)
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
                let remaining = site.blockedEntities.count - trackerIconCount
                SmallCircleText(text: "+\(remaining)")
                    .allowsTightening(true)
                    .minimumScaleFactor(0.5)
                    .visibility(remaining > 0 ? .visible : .gone)
            }
            .padding(.trailing, 6)
            .visibility(site.blockedEntities.isEmpty ? .gone : .visible)

            Group {
                Group {
                    if #available(macOS 12, *) {
                        Text("**\(site.numberOfTrackersBlocked)** tracking attempts blocked")
                    } else {
                        Text("\(site.numberOfTrackersBlocked) tracking attempts blocked")
                    }
                }
                .visibility(site.blockedEntities.isEmpty ? .gone : .visible)

                Text(UserText.homePageNoTrackersFound)
                    .visibility(site.blockedEntities.isEmpty && !site.trackersFound ? .visible : .gone)

                Text(UserText.homePageNoTrackersBlocked)
                    .visibility(site.blockedEntities.isEmpty && site.trackersFound ? .visible : .gone)

            }
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
                .padding([.leading, .trailing], 1)

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

extension Text {

    func optionalUnderline(_ underline: Bool) -> Text {
        if underline {
            return self.underline()
        } else {
            return self
        }
    }

}
