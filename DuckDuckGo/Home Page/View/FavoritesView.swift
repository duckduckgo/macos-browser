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

extension HomePage.Views {

struct Favorites: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    @State var isExpanded = false
    @State var isHovering = false

    var body: some View {

        let addButton =
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.5))
                .frame(width: 64, height: 64)

            VStack {
                HoverButton(size: 64, imageName: "Add", imageSize: 22) {
                    model.addNew()
                }
                .frame(width: 64, height: 64)

                Text(UserText.addFavorite)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .font(.system(size: 10))
                    .frame(height: 32, alignment: .top)
            }
        }.frame(width: 64)

        let ghostButton = VStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                .frame(width: 64, height: 64)
        }.frame(width: 64)

        VStack(alignment: .leading, spacing: 4) {

            ForEach(isExpanded ? model.rows.indices : model.rows.indices.prefix(HomePage.favoritesRowCountWhenCollapsed), id: \.self) { index in

                HStack(alignment: .top, spacing: 20) {
                    ForEach(model.rows[index], id: \.id) { favorite in

                        switch favorite.favoriteType {
                        case .bookmark(let bookmark):
                            if !isExpanded && index + 1 == HomePage.favoritesRowCountWhenCollapsed && favorite.id == model.rows[index].last?.id {
                                addButton
                            } else {
                                Favorite(bookmark: bookmark)
                            }

                        case .addButton:
                            addButton

                        case .ghostButton:
                            ghostButton
                        }
                    }
                }
                
            }

            MoreOrLess(isExpanded: $isExpanded)
                .padding(.top, 12)
                .visibility(model.rows.count > HomePage.favoritesRowCountWhenCollapsed && isHovering ? .visible : .invisible)

        }
        .frame(maxWidth: .infinity)
        .onHover { isHovering in
            self.isHovering = isHovering
        }

    }

}

struct Favorite: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    let bookmark: Bookmark

    @State var isHovering = false

    var body: some View {

        VStack {

            ZStack(alignment: .center) {

                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(isHovering ? Color("ButtonMouseOverColor") : Color("HomeFavoritesBackgroundColor"))

                FaviconView(domain: bookmark.url.host ?? "")
                    .frame(width: 32, height: 32)
                    .padding(9)

            }
            .frame(width: 64, height: 64)
            .clipped()

            Text(bookmark.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .font(.system(size: 10))
                .frame(height: 32, alignment: .top)

        }
        .frame(width: 64)
        .frame(maxWidth: 64)
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
