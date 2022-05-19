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
import Carbon.HIToolbox

private extension Int {
    /// wraps Recent Site index into a ScrollView item identifier
    var siteIndex: HomePage.Views.RecentlyVisited.SiteIndex {
        .init(rawValue: self)
    }
}

extension HomePage.Views {

struct RecentlyVisited: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    @State var isExpanded = true

    struct SiteIndex: RawRepresentable, Hashable {
        let rawValue: Int
    }
    var scrollTo: (SiteIndex) -> Void

    var body: some View {

        VStack(spacing: 0) {
            RecentlyVisitedTitle(isExpanded: $isExpanded)
                .padding(.bottom, 18)

            Group {
                if #available(macOS 11, *) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(zip(model.recentSites.indices, model.recentSites)), id: \.0.siteIndex) { index, site in
                            RecentlyVisitedSite(index: index, site: site) { scrollTo(.init(rawValue: $0)) }
                        }
                    }

                    if !model.recentSites.isEmpty {
                        // Switch focus to the last RecentlyVisited item when Shift+Tabbing into the Home Page
                        Text("").focusable(focusRing: false, onViewFocused: { _ in
                            guard !model.recentSites.isEmpty,
                                  model.focusItem == nil
                            else { return }
                            let index = model.recentSites.count - 1
                            scrollTo(.init(rawValue: index))
                            model.focusChaged(to: true, for: .init(index: index, position: .burn))
                        })
                    }

                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(zip(model.recentSites.indices, model.recentSites)), id: \.0.siteIndex) { index, site in
                            RecentlyVisitedSite(index: index, site: site) { _ in }
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

    private typealias FocusPosition = HomePage.Models.RecentlyVisitedModel.FocusPosition
    private typealias FocusItem = HomePage.Models.RecentlyVisitedModel.FocusItem

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    let index: Int
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel
    var scrollTo: (Int) -> Void
    @State var isHovering = false

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
                    HyperLink(site.domain, textColor: Color("HomeFeedItemTitleColor")) { model.open(site) }
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .permanentlyFocusable(.init(index: index, position: .link), model: model, keyDown: keyboardNavigation) {
                            model.open(site)
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
                .permanentlyFocusable(.init(index: index, position: .favorite), model: model, keyDown: keyboardNavigation) {
                    model.toggleFavoriteSite(site)
                }
                .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                .tooltip(UserText.tooltipAddToFavorites)

                let burn = {
                    if NSApp.keyWindow?.firstResponder is FocusView {
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                    model.focusItem = nil
                    isHovering = false
                    site.isBurning = true
                    withAnimation(.default.delay(0.4)) {
                        site.isHidden = true
                    }
                }

                HoverButton(size: 24, imageName: "Burn", imageSize: 16, cornerRadius: 4, action: burn)
                    .permanentlyFocusable(.init(index: index, position: .burn), model: model, keyDown: keyboardNavigation, action: burn)
                    .foregroundColor(Color("HomeFeedItemButtonTintColor"))
                    .tooltip(UserText.tooltipBurn)

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

    // MARK: Full Keyboard Access

    private func keyboardNavigation(event: NSEvent) -> NSEvent? {
        switch Int(event.keyCode) {
        case kVK_UpArrow:
            if NSApp.isCommandPressed || NSApp.isOptionPressed {
                self.selectFirstItem()
            } else {
                selectPreviousItem()
            }
        case kVK_DownArrow:
            if NSApp.isCommandPressed || NSApp.isOptionPressed {
                self.selectLastItem()
            } else {
                selectNextItem()
            }
        case kVK_Tab:
            if NSApp.isShiftPressed {
                selectPreviousKeyView()
            } else {
                selectNextKeyView()
            }
            return nil
        default:
            return event
        }
        return nil
    }

    private func moveFocus(to position: FocusPosition, at index: Int) {
        let focusItem = FocusItem(index: index, position: position)

        if #available(macOS 12, *) {
            scrollTo(index)
            model.focusChaged(to: true, for: focusItem)
            return
        }

        guard let window = NSApp.keyWindow,
              let firstResponder = window.firstResponder as? NSView,
              let scrollView = firstResponder.enclosingScrollView,
              let view = scrollView.viewWithTag(focusItem.tag)
        else {
            return
        }

        view.makeMeFirstResponder()
    }

    private func selectPreviousKeyView() {
        let focusItem = model.focusItem ?? FocusItem(index: 0, position: .link)

        switch focusItem.position {
        case .link:
            if focusItem.index == 0 {
                guard let firstResponder = NSApp.keyWindow?.firstResponder as? NSView,
                    let expandButton = firstResponder.enclosingScrollView?.viewWithTag(RecentlyVisitedTitle.buttonTag)
                else { return }
                expandButton.makeMeFirstResponder()
                return
            }
            moveFocus(to: .burn, at: index - 1)
        case .favorite:
            moveFocus(to: .link, at: index)
        case .burn:
            moveFocus(to: .favorite, at: index)
        }
    }

    private func selectNextKeyView() {
        switch (model.focusItem?.position, model.focusItem?.index) {
        case (.none, _), (_, .none):
            moveFocus(to: .link, at: 0)
        case (.link, .some(let index)):
            moveFocus(to: .favorite, at: index)
        case (.favorite, .some(let index)):
            moveFocus(to: .burn, at: index)
        case (.burn, .some(let index)):
            if index + 1 < model.recentSites.count {
                moveFocus(to: .link, at: index + 1)
            } else {
                NSApp.keyWindow?.selectNextKeyView(nil)
            }
        }
    }

    private func selectPreviousItem() {
        if (model.focusItem?.index ?? 0) > 0 {
            self.moveFocus(to: .link, at: model.focusItem!.index - 1)
        } else if !model.recentSites.isEmpty {
            self.moveFocus(to: .link, at: model.recentSites.count - 1)
        }
    }

    private func selectNextItem() {
        if (model.focusItem?.index ?? 0) + 1 < model.recentSites.count {
            self.moveFocus(to: .link, at: (model.focusItem?.index ?? 0) + 1)
        } else if !model.recentSites.isEmpty {
            self.moveFocus(to: .link, at: 0)
        }
    }

    private func selectFirstItem() {
        guard !model.recentSites.isEmpty else { return }
        self.moveFocus(to: .link, at: 0)
    }

    private func selectLastItem() {
        guard !model.recentSites.isEmpty else { return }
        self.moveFocus(to: .link, at: model.recentSites.count - 1)
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
    static let buttonTag = 114

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

            let toggleSection = {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            HoverButton(size: 24, imageName: "HomeArrowUp", imageSize: 16, cornerRadius: 4, action: toggleSection)
                .rotationEffect(.degrees(isExpanded ? 0 : 180))
                .focusable(tag: Self.buttonTag, action: toggleSection)

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

private extension View {
    typealias Model = HomePage.Models.RecentlyVisitedModel
    typealias FocusItem = HomePage.Models.RecentlyVisitedModel.FocusItem

    @ViewBuilder
    func permanentlyFocusable(_ item: FocusItem, model: Model, keyDown: ((NSEvent) -> NSEvent?)?, action: (() -> Void)?) -> some View {
        let isFocused = model.focusItem == item
        let tag = item.tag
        let onFocus = { model.focusChaged(to: $0, for: item) }

        // macOS 11 supports LazyVStack causing focus views to be removed on scroll out
        // that‘s why we add a fake Focus View directly to the scroll view
        if #available(macOS 11.0, *) {
            self.focusable(focusRing: false, onViewFocused: { focusView in
                makeFakeFocusView(withTag: tag, for: focusView, action: action, keyDown: keyDown, onFocusLost: { onFocus(false) })
                onFocus(true)
            }, onAppear: { view in
                // Tabbing to a view located in currently invisible scroll area will trigger this onAppear callback where we call
                // view.makeMeFirstResponder() triggering Fake Focus View creation above
                guard isFocused else { return }

                if let focusView = view.window?.firstResponder as? FocusView,
                    focusView.tag == tag {
                    // Fake Focus View is already shown and focused
                } else {
                    view.makeMeFirstResponder()
                }
            })
        } else {
            // regular VStack allows us to stick with a simple Focus View
            self.focusable(tag: tag, onFocus: onFocus, action: action, keyDown: keyDown)
        }
    }

    func makeFakeFocusView(withTag tag: Int,
                           for view: FocusView,
                           action: (() -> Void)?,
                           keyDown: ((NSEvent) -> NSEvent?)?,
                           onFocusLost: @escaping (() -> Void)) {
        guard let scrollView = view.enclosingScrollView else { return }

        let frame = scrollView.contentView.convert(view.bounds, from: view)
        let fakeFocusView = FocusView(tag: tag, frame: frame)
        scrollView.contentView.addSubview(fakeFocusView)
        fakeFocusView.shouldDrawFocusRing = true
        fakeFocusView.onKeyDown = keyDown
        fakeFocusView.defaultAction = action
        fakeFocusView.makeMeFirstResponder()
        fakeFocusView.tag = tag

        DispatchQueue.main.async { [window=scrollView.window] in
            window?.recalculateKeyViewLoop()
        }

        fakeFocusView.onFocus = { view, isFirstResponder in
            if !isFirstResponder, view.superview != nil {
                view.removeFromSuperview()
                onFocusLost()
            }
        }
    }

}
