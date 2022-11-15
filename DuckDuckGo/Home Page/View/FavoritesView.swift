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

    static let gridItemWidth: CGFloat = 64
    static let gridSpacing: CGFloat = 10
    static let gridHorizontalSpacing: CGFloat = 20
    static let gridItemHeight: CGFloat = 101

    var body: some View {

        if #available(macOS 11.0, *) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.gridItemWidth), spacing: Self.gridHorizontalSpacing), count: HomePage.favoritesPerRow), spacing: Self.gridSpacing) {
                ForEach(model.visibleModels, content: \.favoriteView)
            }
            .frame(maxWidth: (Self.gridItemWidth + Self.gridHorizontalSpacing) * CGFloat(HomePage.favoritesPerRow) - Self.gridHorizontalSpacing)
            .simultaneousGesture(dragGesture)
        } else {
            ForEach(rowIndices, id: \.self) { index in
                HStack(alignment: .top, spacing: Self.gridHorizontalSpacing) {
                    ForEach(model.rows[index], id: \.id, content: \.favoriteView)
                }
            }
        }

        MoreOrLess(isExpanded: $model.showAllFavorites)
            .padding(.top, 2)
            .visibility(model.rows.count > HomePage.favoritesRowCountWhenCollapsed && isHovering ? .visible : .invisible)

    }

    // MARK: - Reordering

    @State private var draggedFavorite: HomePage.Models.FavoriteModel?

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged(updateDrag)
            .onEnded(endDrag)
    }

    private func updateDrag(_ value: DragGesture.Value) {
        if draggedFavorite == nil {
            let draggedFavoriteIndex = itemIndex(for: value.startLocation)
            draggedFavorite = model.models[draggedFavoriteIndex]
        }
        guard let draggedFavorite = draggedFavorite, let from = model.models.firstIndex(of: draggedFavorite) else {
            return
        }
        let to = itemIndex(for: value.location)

        if to != from, model.models[to] != draggedFavorite {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.models.move(fromOffsets: IndexSet(integer: from),
                                  toOffset: to > from ? to + 1 : to)
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        defer {
            draggedFavorite = nil
        }
        guard case let .bookmark(bookmark) = draggedFavorite?.favoriteType else {
            return
        }
        let from = itemIndex(for: value.startLocation)
        let index = itemIndex(for: value.location)

        let correctedIndex = index > from ? index + 1 : index
        model.moveFavorite(bookmark, correctedIndex)
    }

    private func itemIndex(for point: CGPoint) -> Int {
        let constrainedPoint = pointConstrainedToFavoritesView(point)

        let row = row(for: constrainedPoint.y)
        let column = column(for: constrainedPoint.x)
        let index = row * HomePage.favoritesPerRow + column

        return max(0, min(index, model.favorites.count - 1))
    }

    private func pointConstrainedToFavoritesView(_ point: CGPoint) -> CGPoint {
        let rowCount = model.showAllFavorites ? model.favorites.count / HomePage.favoritesPerRow : 1
        let width = (Self.gridItemWidth + 20) * CGFloat(HomePage.favoritesPerRow) - 20
        let height = (Self.gridItemHeight + Self.gridSpacing) * CGFloat(rowCount) - Self.gridSpacing

        var constrainedPoint = point
        constrainedPoint.x = max(0, min(width, point.x))
        constrainedPoint.y = max(0, min(height, point.y))
        return constrainedPoint
    }

    private func column(for x: CGFloat) -> Int {
        if x < (Self.gridItemWidth + Self.gridHorizontalSpacing / 2) {
            return 0
        }
        var column = 1
        let value = x - (Self.gridItemWidth + Self.gridHorizontalSpacing / 2)
        column += Int(value) / Int(Self.gridItemWidth + Self.gridHorizontalSpacing)
        return column
    }

    private func row(for y: CGFloat) -> Int {
        if y < (Self.gridItemHeight + Self.gridSpacing / 2) {
            return 0
        }
        var row = 1
        let value = y - (Self.gridItemHeight + Self.gridSpacing / 2)
        row += Int(value) / Int(Self.gridItemHeight + Self.gridSpacing)
        return row
    }
}
    
fileprivate struct FavoritesGridAddButton: View {
    
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
    
fileprivate struct FavoritesGridGhostButton: View {
    
    var body: some View {
        
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                .frame(width: 64, height: 64)
            Spacer()
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

extension HomePage.Models.FavoriteModel {

    @ViewBuilder
    var favoriteView: some View {
        switch favoriteType {
        case .bookmark(let bookmark):
            HomePage.Views.Favorite(bookmark: bookmark)

        case .addButton:
            HomePage.Views.FavoritesGridAddButton()

        case .ghostButton:
            HomePage.Views.FavoritesGridGhostButton()
        }
    }
}
