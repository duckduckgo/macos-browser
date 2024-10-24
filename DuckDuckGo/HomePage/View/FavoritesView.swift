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
import SwiftUIExtensions

extension HomePage.Views {

struct Favorites: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    @State var isHovering = false

    var rowIndices: Range<Int> {
        model.showAllFavorites ? model.rows.indices : model.rows.indices.prefix(HomePage.favoritesRowCountWhenCollapsed)
    }

    var body: some View {

        if #available(macOS 12.0, *) {
            LazyVStack(spacing: 0) {
                FavoritesGrid(isHovering: $isHovering)
            }
            .frame(maxWidth: .infinity)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        } else {
            VStack(spacing: 0) {
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

        if #available(macOS 12.0, *) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(GridDimensions.itemWidth), spacing: GridDimensions.horizontalSpacing), count: HomePage.favoritesPerRow),
                spacing: GridDimensions.verticalSpacing
            ) {
                ForEach(model.visibleModels, content: \.favoriteView)
            }
            .frame(maxWidth: GridDimensions.width)
            .simultaneousGesture(dragGesture)
        } else {
            ForEach(rowIndices, id: \.self) { index in
                HStack(alignment: .top, spacing: GridDimensions.horizontalSpacing) {
                    ForEach(model.rows[index], id: \.id, content: \.favoriteView)
                }
            }
        }

        MoreOrLess(isExpanded: $model.showAllFavorites)
            .padding(.top, -3)
            .visibility(moreOrLessButtonVisibility)
    }

    var moreOrLessButtonVisibility: ViewVisibility {
        let thresholdFavoritesCount = HomePage.favoritesRowCountWhenCollapsed * HomePage.favoritesPerRow
        return (isHovering && model.models.count > thresholdFavoritesCount) ? .visible : .invisible
    }

    enum GridDimensions {
        static let itemWidth: CGFloat = 64
        static let itemHeight: CGFloat = 101
        static let verticalSpacing: CGFloat = 10
        static let horizontalSpacing: CGFloat = 24

        static let width: CGFloat = (itemWidth + horizontalSpacing) * CGFloat(HomePage.favoritesPerRow) - horizontalSpacing

        static func height(for rowCount: Int) -> CGFloat {
            (itemHeight + verticalSpacing) * CGFloat(rowCount) - verticalSpacing
        }
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
            let draggedFavoriteIndex = favoriteIndex(for: value.startLocation, forExistingFavoriteOnly: false)
            draggedFavorite = model.models[safe: draggedFavoriteIndex]
        }
        guard let draggedFavorite = draggedFavorite,
              case .bookmark = draggedFavorite.favoriteType,
              let from = model.models.firstIndex(of: draggedFavorite)
        else {
            return
        }

        let to: Int = {
            let index = favoriteIndex(for: value.location)
            return index > from ? index + 1 : index
        }()

        // `to` technically cannot point to an index outside of models array bounds,
        // because there's always at least the "Add Favorite" button at the end,
        // but we're using [safe:] subscript to not crash if the button ever gets removed.
        if to != from, model.models[safe: to] != draggedFavorite {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.models.move(fromOffsets: IndexSet(integer: from), toOffset: to)
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
        let from = favoriteIndex(for: value.startLocation)
        let to: Int = {
            let index = favoriteIndex(for: value.location)
            return index > from ? index + 1 : index
        }()

        // `to` can point to an index outside of array bounds, in which case it means move to the end.
        if to != from, model.favorites[safe: to] != bookmark {
            model.moveFavorite(bookmark, to)
        }
    }

    private func favoriteIndex(for point: CGPoint, forExistingFavoriteOnly: Bool = true) -> Int {
        let pointInView = pointConstrainedToFavoritesView(point)

        let row = row(for: pointInView.y)
        let column = column(for: pointInView.x)
        let index = row * HomePage.favoritesPerRow + column

        return forExistingFavoriteOnly ? max(0, min(index, model.favorites.count - 1)) : index
    }

    private func pointConstrainedToFavoritesView(_ point: CGPoint) -> CGPoint {
        let rowCount: Int = {
            if model.showAllFavorites {
                var count = model.models.count / HomePage.favoritesPerRow
                if model.models.count % HomePage.favoritesPerRow > 0 {
                    count += 1
                }
                return count
            }
            return HomePage.favoritesRowCountWhenCollapsed
        }()
        let height = GridDimensions.height(for: rowCount)

        var constrainedPoint = point
        constrainedPoint.x = max(0, min(GridDimensions.width, point.x))
        constrainedPoint.y = max(0, min(height, point.y))
        return constrainedPoint
    }

    private func column(for x: CGFloat) -> Int {
        if x < (GridDimensions.itemWidth + GridDimensions.horizontalSpacing / 2) {
            return 0
        }
        var column = 1
        let value = x - (GridDimensions.itemWidth + GridDimensions.horizontalSpacing / 2)
        column += Int(value) / Int(GridDimensions.itemWidth + GridDimensions.horizontalSpacing)
        return column
    }

    private func row(for y: CGFloat) -> Int {
        if y < (GridDimensions.itemHeight + GridDimensions.verticalSpacing / 2) {
            return 0
        }
        var row = 1
        let value = y - (GridDimensions.itemHeight + GridDimensions.verticalSpacing / 2)
        row += Int(value) / Int(GridDimensions.itemHeight + GridDimensions.verticalSpacing)
        return row
    }
}

fileprivate struct FavoritesGridAddButton: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    var body: some View {

        ZStack(alignment: .top) {
            FavoriteTemplate(title: UserText.addFavorite, url: nil, onFaviconMissing: model.onFaviconMissing)
            ZStack {
                Image(.add)
                    .resizable()
                    .frame(width: 22, height: 22)
            }.frame(width: FavoritesGrid.GridDimensions.itemWidth, height: FavoritesGrid.GridDimensions.itemWidth)
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
                .stroke(Color(.homeFavoritesGhost), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                .frame(width: FavoritesGrid.GridDimensions.itemWidth, height: FavoritesGrid.GridDimensions.itemWidth)
            Spacer()
        }
        .frame(width: FavoritesGrid.GridDimensions.itemWidth, height: FavoritesGrid.GridDimensions.itemHeight)

    }

}

struct FavoriteTemplate: View {

    let title: String
    let url: URL?
    let onFaviconMissing: (() -> Void)?

    @State var isHovering = false {
        didSet {
            guard isHovering != oldValue else {
                return
            }
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pointingHand.pop()
            }
        }
    }

    @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

    var body: some View {
        VStack(spacing: 5) {

            ZStack(alignment: .center) {

                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                        .shadow(color: isHovering ? .clear : .black.opacity(0.16), radius: 1.5, x: 0, y: 0)
                        .shadow(color: isHovering ? .clear : .black.opacity(0.12), radius: 2, x: 0, y: 2)

                    RoundedRectangle(cornerRadius: 12)
                        .homePageViewBackground(settingsModel.customBackground)
                        .cornerRadius(12)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? .buttonMouseOver : .clear)
                    .homePageViewBackground(settingsModel.customBackground)
                    .cornerRadius(12)

                if let url = url {
                    FaviconView(url: url, onFaviconMissing: onFaviconMissing)
                        .frame(width: 32, height: 32)
                        .padding(9)
                }
            }
            .frame(width: FavoritesGrid.GridDimensions.itemWidth, height: FavoritesGrid.GridDimensions.itemWidth)

            Text(title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .font(.system(size: 11))
                .frame(height: 32, alignment: .top)

        }
        .frame(width: FavoritesGrid.GridDimensions.itemWidth)
        .frame(maxWidth: FavoritesGrid.GridDimensions.itemWidth)
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

}

struct Favorite: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    let bookmark: Bookmark

    // Maintain separate copies of bookmark metadata required by the view, in order to ensure that SwiftUI re-renders correctly.
    // Do not remove these properties even if some are not used in the `FavoriteTemplate` view as the view will not re-render correctly.
    private let bookmarkTitle: String
    private let bookmarkURL: URL
    private let bookmarkParentFolder: String?

    init?(bookmark: Bookmark) {
        guard let urlObject = bookmark.urlObject else { return nil }
        self.bookmark = bookmark
        self.bookmarkTitle = bookmark.title
        self.bookmarkURL = urlObject
        self.bookmarkParentFolder = bookmark.parentFolderUUID
    }

    var body: some View {

        FavoriteTemplate(title: bookmarkTitle, url: bookmark.urlObject, onFaviconMissing: model.onFaviconMissing)
            .link {
                model.open(bookmark)
            }.contextMenu(ContextMenu(menuItems: {
                Button(UserText.openInNewTab, action: { model.openInNewTab(bookmark) }).accessibilityIdentifier("HomePage.Views.openInNewTab")
                Button(UserText.openInNewWindow, action: { model.openInNewWindow(bookmark) }).accessibilityIdentifier("HomePage.Views.openInNewWindow")
                Divider()
                Button(UserText.edit, action: { model.edit(bookmark) }).accessibilityIdentifier("HomePage.Views.editBookmark")
                Button(UserText.removeFavorite, action: { model.removeFavorite(bookmark) }).accessibilityIdentifier("HomePage.Views.removeFavorite")
                Button(UserText.deleteBookmark, action: { model.deleteBookmark(bookmark) }).accessibilityIdentifier("HomePage.Views.deleteBookmark")
            }))

    }

}

}

extension HomePage.Models.FavoriteModel {

    @ViewBuilder
    var favoriteView: some View {
        switch favoriteType {
        case .bookmark(let bookmark):
            HomePage.Views.Favorite(bookmark: bookmark)?.accessibilityIdentifier("HomePage.Models.FavoriteModel.\(bookmark.title)")

        case .addButton:
            HomePage.Views.FavoritesGridAddButton().accessibilityIdentifier("HomePage.Models.FavoriteModel.addButton")

        case .ghostButton:
            HomePage.Views.FavoritesGridGhostButton().accessibilityIdentifier("HomePage.Models.FavoriteModel.ghostButton")
        }
    }
}
