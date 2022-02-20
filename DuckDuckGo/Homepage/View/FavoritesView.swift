//
//  FavoritesView.swift
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

extension Homepage.Views {

struct Favorites: View {

    @EnvironmentObject var model: Homepage.Models.FavoritesModel

    @State var expanded = false
    @State var isHovering = false

    var body: some View {

        let addButton = VStack {
            HoverButton(size: 72, backgroundColor: Color("HomeFavoritesBackgroundColor"), imageName: "Add", imageSize: 22) {
                model.addNew()
            }
            Text(UserText.addFavorite)
                .font(.system(size: 10))
        }

        VStack(alignment: .leading, spacing: 0) {

            ForEach(expanded ? model.rows.indices : model.rows.indices.prefix(Homepage.favoritesRowCountWhenCollapsed), id: \.self) { index in
                HStack(alignment: .top, spacing: 29) {
                    ForEach(model.rows[index], id: \.id) { favorite in
                        if !expanded && index + 1 == Homepage.favoritesRowCountWhenCollapsed && favorite.id == model.rows[index].last?.id {
                            addButton
                        } else if let bookmark = favorite.bookmark {
                            Favorite(bookmark: bookmark)
                        } else if favorite.id == Homepage.Models.FavoriteModel.addButtonUUID {
                            addButton
                        } else {
                            FailedAssertionView("Unknown favorites type")
                        }
                    }

                    Spacer()
                }
                .frame(height: 112)
            }

            MoreOrLess(moreIsUp: true, expanded: $expanded)
                .visibility(model.rows.count > Homepage.favoritesRowCountWhenCollapsed && isHovering ? .visible : .invisible)

        }.onHover { isHovering in
            self.isHovering = isHovering
        }
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
            Button(UserText.openInNewTab, action: { model.openInNewTab(bookmark) })
            Button(UserText.openInNewWindow, action: { model.openInNewWindow(bookmark) })
            Divider()
            Button(UserText.edit, action: { model.edit(bookmark) })
            Button(UserText.remove, action: { model.remove(bookmark) })
        }))

    }

}

}
