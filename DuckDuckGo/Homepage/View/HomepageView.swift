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

extension Homepage.Views {

struct RootView: View {

    var body: some View {

        GeometryReader { geometry in
            ZStack {
                Group {
                    ScrollView {
                        VStack(spacing: 0) {
                            PrivacySummary()

                            Favorites()
                                .frame(maxWidth: 512)
                                .padding(.top, max(48, geometry.size.height * 0.29))

                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                DefaultBrowserPrompt()
            }
            .frame(maxWidth: .infinity)
            .background(Color("NewTabPageBackgroundColor"))
        }
     }

}

struct DefaultBrowserPrompt: View {

    @EnvironmentObject var model: Homepage.Models.DefaultBrowserModel

    var body: some View {

        VStack {
            Spacer()

            HStack {
                HoverButton(imageName: "Close", imageSize: 22) {
                    self.model.close()
                }.padding()

                Spacer()

                Image("Logo")
                    .resizable(resizingMode: .stretch)
                    .frame(width: 38, height: 38)

                Text("Set DuckDuckGo as your default browser")
                    .font(.body)

                let button = Button("Set Default...") {
                    self.model.requestSetDefault()
                }

                if #available(macOS 12.0, *) {
                    button.buttonStyle(.borderedProminent)
                } else {
                    button.buttonStyle(.bordered)
                }

                Spacer()
            }
            .background(Color("BrowserTabBackgroundColor").shadow(radius: 3))

        }.visibility(model.shouldShow ? .visible : .gone)
        
    }

}

struct PrivacySummary: View {

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Image("HomeShield")
            Text("DuckDuckGo blocks trackers as you browse")
                .fontWeight(.bold)
        }
        .foregroundColor(.primary.opacity(0.4))
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
            timer.upstream.connect().cancel()
            refreshImage()
        }

    }

}

struct HoverButton: View {

    let size: CGFloat
    let backgroundColor: Color
    let imageName: String
    let imageSize: CGFloat?
    let action: () -> Void

    @State var isHovering = false

    init(size: CGFloat = 32, backgroundColor: Color = Color.clear, imageName: String, imageSize: CGFloat? = nil, action: @escaping () -> Void) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.imageName = imageName
        self.imageSize = imageSize
        self.action = action
    }

    var body: some View {
        Group {
            Group {
                if let image = NSImage(named: imageName) {
                    Image(nsImage: image)
                        .resizable()
                } else if #available(macOS 11, *) {
                    Image(systemName: imageName)
                        .resizable()
                }
            }
            .frame(width: imageSize ?? size, height: imageSize ?? size)

        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .background(RoundedRectangle(cornerRadius: 8).foregroundColor(isHovering ? Color("ButtonMouseOverColor") : backgroundColor))
        .link(onHoverChanged: {
            self.isHovering = $0
        }) {
            action()
        }

    }

}

struct Favorites: View {

    @EnvironmentObject var model: Homepage.Models.FavoritesModel

    @State var expanded = false
    @State var isHovering = false

    var body: some View {

        let addButton = VStack {
            HoverButton(size: 72, backgroundColor: Color("HomeFavoritesBackgroundColor"), imageName: "Add", imageSize: 22) {
                model.addNew()
            }
            Text("Add Favorite")
                .font(.system(size: 10))
        }

        VStack(alignment: .leading, spacing: 12) {

            ForEach(expanded ? model.rows.indices : model.rows.indices.prefix(Homepage.favoritesRowCountWhenCollapsed), id: \.self) { index in
                HStack(alignment: .top, spacing: 29) {
                    ForEach(model.rows[index], id: \.id) { favorite in
                        if let bookmark = favorite.bookmark {
                            Favorite(bookmark: bookmark)
                        } else if favorite.id == Homepage.Models.FavoriteModel.addButtonUUID {
                            addButton
                        } else {
                            FailedAssertionView("Unknown favorites type")
                        }
                    }

                    Spacer()
                }
            }

            MoreOrLess(moreIsUp: true, expanded: $expanded)
                .visibility(model.rows.count > Homepage.favoritesRowCountWhenCollapsed && isHovering ? .visible : .invisible)

        }.onHover { isHovering in
            self.isHovering = isHovering
        }
    }

}

struct FailedAssertionView: View {

    var body: some View {
        EmptyView()
    }

    init(_ message: String) {
        assertionFailure(message)
    }

}

struct Favorite: View {

    @EnvironmentObject var model: Homepage.Models.FavoritesModel

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
        .link(onHoverChanged: {
            isHovering = $0
        }) {
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
