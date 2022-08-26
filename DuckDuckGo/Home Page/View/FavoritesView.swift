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

    @State var isHovering = false

    var rowIndices: Range<Int> {
        model.showAllFavorites ? model.rows.indices : model.rows.indices.prefix(HomePage.favoritesRowCountWhenCollapsed)
    }

    var body: some View {

        if #available(macOS 11.0, *) {
            LazyVStack(spacing: 4) {
                FavoritesGrid(isHovering: $isHovering)
            }
            .frame(maxWidth: .infinity)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        } else {
            VStack(spacing: 4) {
                FavoritesGrid(isHovering: $isHovering)
            }
            .frame(maxWidth: .infinity)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }

    }

}
    
struct FavoritesGrid: View {
    
    @EnvironmentObject var model: HomePage.Models.FavoritesModel
    
    @Binding var isHovering: Bool
    
    var rowIndices: Range<Int> {
        model.showAllFavorites ? model.rows.indices : model.rows.indices.prefix(HomePage.favoritesRowCountWhenCollapsed)
    }

    var body: some View {

        ForEach(rowIndices, id: \.self) { index in

            HStack(alignment: .top, spacing: 20) {
                ForEach(model.rows[index], id: \.id) { favorite in

                    switch favorite.favoriteType {
                    case .bookmark(let bookmark):
                        Favorite(bookmark: bookmark)

                    case .addButton:
                        FavoritesGridAddButton()

                    case .ghostButton:
                        FavoritesGridGhostButton()
                    }
                }
            }
            
        }

        MoreOrLess(isExpanded: $model.showAllFavorites)
            .padding(.top, 2)
            .visibility(model.rows.count > HomePage.favoritesRowCountWhenCollapsed && isHovering ? .visible : .invisible)

    }
    
}
    
private struct FavoritesGridAddButton: View {
    
    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    var body: some View {
        
        ZStack(alignment: .top) {
            FavoriteTemplate(title: UserText.addFavorite, domain: nil)
            ZStack {
                Image("Add")
                    .resizable()
                    .frame(width: 22, height: 22)
            }.frame(width: 64, height: 64)
        }
        .link {
            model.addNew()
        }
        
    }
    
}
    
private struct FavoritesGridGhostButton: View {
    
    var body: some View {
        
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                .frame(width: 64, height: 64)
        }
        .frame(width: 64)
        
    }
    
}

struct FavoriteTemplate: View {

    let title: String
    let domain: String?

    @State var isHovering = false

    var body: some View {
        VStack(spacing: 5) {

            ZStack(alignment: .center) {

                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(isHovering ? Color("HomeFavoritesHoverColor") : Color("HomeFavoritesBackgroundColor"))

                if let domain = domain {
                    FaviconView(domain: domain)
                        .frame(width: 32, height: 32)
                        .padding(9)
                }
            }
            .frame(width: 64, height: 64)
            .clipped()

            Text(title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .font(.system(size: 11))
                .frame(height: 32, alignment: .top)

        }
        .frame(width: 64)
        .frame(maxWidth: 64)
        .onHover { isHovering in
            self.isHovering = isHovering
            
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pointingHand.pop()
            }

        }
    }

}

struct Favorite: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    let bookmark: Bookmark

    var body: some View {

        FavoriteTemplate(title: bookmark.title, domain: bookmark.url.host)
            .link {
                model.open(bookmark)
            }.contextMenu(ContextMenu(menuItems: {
                Button(UserText.openInNewTab, action: { model.openInNewTab(bookmark) })
                Button(UserText.openInNewWindow, action: { model.openInNewWindow(bookmark) })
                Divider()
                Button(UserText.edit, action: { model.edit(bookmark) })
                Button(UserText.removeFavorite, action: { model.removeFavorite(bookmark) })
                Button(UserText.deleteBookmark, action: { model.deleteBookmark(bookmark) })
            }))

    }

}

}
