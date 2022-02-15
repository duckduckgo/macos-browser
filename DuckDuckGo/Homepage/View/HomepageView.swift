//
//  HomepageView.swift
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
import BrowserServicesKit

struct Homepage {

struct RootView: View {

    @State var sidebarVisible = true

    var body: some View {

        Group {
            ScrollView {
                VStack {
                    VStack(alignment: .leading, spacing: 24) {

                        Favorites()

                        Spacer()
                    }
                    .frame(maxWidth: 512)
                    .padding(.top, 48)
                }.frame(maxWidth: .infinity)
            }

        }
        .frame(maxWidth: .infinity)
        .background(Color("NewTabPageBackgroundColor"))
     }

}

struct SystemImage: View {

    let named: String?
    let fallback: String
    let help: String

    var body: some View {
        Group {
            if #available(macOS 11, *) {
                Group {
                    if let nsImage = NSImage(systemSymbolName: named ?? "", accessibilityDescription: nil) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(fallback)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }.help(help)
            } else {
                Image(fallback)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }

}

struct MoreOrLess: View {

    let moreIsUp: Bool

    @Binding var expanded: Bool

    var upRotation: Double {
        moreIsUp ? 0 : 180
    }

    var downRotation: Double {
        moreIsUp ? 180 : 0
    }

    var body: some View {

        HStack {
            Text(expanded ? "Less" : "More")
            Group {
                if #available(macOS 11.0, *) {
                    Image(systemName: "chevron.up")
                } else {
                    Text("^")
                }
            }
            .rotationEffect(.degrees(expanded ? upRotation : downRotation))
        }
        .font(.system(size: 11, weight: .light))
        .foregroundColor(.secondary)
        .link {
            withAnimation {
                expanded = !expanded
            }
        }

    }

}

struct FaviconView: View {

    let faviconManagement: FaviconManagement = FaviconManager.shared

    let domain: String
    let size: CGFloat

    @State var image: NSImage?
    @State private var timer = Timer.publish(every: 0.3, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    init(domain: String, size: CGFloat = 32) {
        self.domain = domain
        self.size = size
    }

    func refreshImage() {
        image = faviconManagement.getCachedFavicon(for: domain, sizeCategory: .small)?.image
    }

    var body: some View {

        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(4.0)
                    .onReceive(timer) { _ in
                        refreshImage()
                        timer.upstream.connect().cancel()
                    }
            } else {

                ZStack {
                    Rectangle()
                        .foregroundColor(Color.forDomain(domain))
                    Text(String(domain.capitalized.first ?? "?"))
                        .font(.title)
                        .foregroundColor(Color.white)
                }
                .frame(width: size, height: size)
                .cornerRadius(4.0)

            }
        }.onAppear {
            refreshImage()
        }.onReceive(timer) { _ in
            refreshImage()
        }

    }

}

struct HoverButton: View {

    let size: CGFloat
    let backgroundColor: Color
    let imageName: String
    let action: () -> Void

    @State var isHovering = false

    init(size: CGFloat = 32, backgroundColor: Color = Color.clear, imageName: String, action: @escaping () -> Void) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.imageName = imageName
        self.action = action
    }

    var body: some View {

        Group {
            if let image = NSImage(named: imageName) {
                Image(nsImage: image)
            } else if #available(macOS 11, *) {
                Image(systemName: imageName)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .background(RoundedRectangle(cornerRadius: 8).foregroundColor(isHovering ? Color("ButtonMouseOverColor") : backgroundColor))
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .link {
            action()
        }

    }

}

struct Favorites: View {

    @EnvironmentObject var model: HomepageModels.FavoritesModel

    @State var expanded = false
    @State var isHovering = false

    var body: some View {

        let addButton = VStack {
            HoverButton(size: 72, backgroundColor: Color("HomeFavoritesBackgroundColor"), imageName: "Add") {
                model.addNew()
            }
            Text("Add")
                .font(.system(size: 10))
        }

        VStack(alignment: .leading, spacing: 12) {

            ForEach(expanded ? model.rows.indices : model.rows.indices.prefix(1), id: \.self) { index in
                HStack(alignment: .top, spacing: 29) {

                    ForEach(model.rows[index], id: \.id) { favorite in
                        if !expanded && favorite == model.rows[index].last {
                            addButton
                        } else {
                            Favorite(bookmark: favorite)
                        }
                    }

                    if expanded && model.rows[index].count < HomepageModels.favoritesPerRow {
                        addButton
                    }
                }
            }

            MoreOrLess(moreIsUp: true, expanded: $expanded)
                .visibility(model.rows.count > 1 && isHovering ? .visible : .invisible)

        }.onHover { isHovering in
            self.isHovering = isHovering
        }
    }

}

struct Favorite: View {

    @EnvironmentObject var model: HomepageModels.FavoritesModel

    let size: CGFloat = 72

    let bookmark: Bookmark

    @State var isHovering = false

    var body: some View {

        VStack {

            ZStack(alignment: .center) {

                FaviconView(domain: bookmark.url.host ?? "", size: 72)
                    .frame(width: size, height: size)
                    .padding(9)
                    .cornerRadius(8)
                    .blur(radius: isHovering ? 30 : 50)

                FaviconView(domain: bookmark.url.host ?? "")
                    .frame(width: 32, height: 32)
                    .padding(9)

            }
            .frame(width: size, height: size)
            .cornerRadius(8)
            .clipped()

            Text(bookmark.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
                .font(.system(size: 10))

        }
        .frame(width: size)
        .link {
            model.open(bookmark)
        }.contextMenu(ContextMenu(menuItems: {
            Button("Open in New Tab", action: { model.openInNewTab(bookmark) })
            Button("Open in New Window", action: { model.openInNewWindow(bookmark) })
            Divider()
            Button("Edit", action: { model.edit(bookmark) })
            Button("Remove", action: { model.remove(bookmark) })
        }))

    }

}

}
