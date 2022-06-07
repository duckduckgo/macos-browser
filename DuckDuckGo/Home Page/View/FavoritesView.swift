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
import Carbon.HIToolbox

extension HomePage.Views {

struct Favorites: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    @State var isHovering = false

    var rowIndices: Range<Int> {
        model.showAllFavorites ? model.rows.indices : model.rows.indices.prefix(HomePage.favoritesRowCountWhenCollapsed)
    }

    var body: some View {

        VStack(spacing: 4) {

            ForEach(rowIndices, id: \.self) { row in

                HStack(alignment: .top, spacing: 20) {
                    ForEach(Array(zip(model.rows[row].indices, model.rows[row])), id: \.0) { index, favorite in
                        let tag = FavoriteTemplate.tagBase + row * HomePage.favoritesPerRow + index
                        switch favorite {
                        case .bookmark(let bookmark):
                            Favorite(bookmark: bookmark, tag: tag) { model.open(bookmark) }

                        case .addButton:
                            FavoriteTemplate(title: UserText.addFavorite, domain: nil, image: Image("Add"), size: 22, tag: tag) {
                                model.addNew()
                            }

                        case .ghostButton:
                            VStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                                    .frame(width: 64, height: 64)
                            }.frame(width: 64)

                        }
                    }
                }

            }

            let canShowMore = model.rows.count > HomePage.favoritesRowCountWhenCollapsed
            MoreOrLess(isExpanded: $model.showAllFavorites, isVisible: isHovering || model.isHomeViewFirstResponder)
                .padding(.top, 2)
                // keep an empty button visible for VoiceOver
                .visibility(canShowMore ? .visible : .invisible)

        }
        .accessibilityElement(children: .contain)
        .accessibility(identifier: "FavoritesList")
        .accessibility(label: .init(UserText.favorites))
        .frame(maxWidth: .infinity)
        .onHover(update: $isHovering)

    }

}

struct FavoriteTemplate: View {

    static let tagBase = HomePage.favoritesPerRow * 10000

    private enum KeyViewDirection {
        case left
        case leftMost
        case right
        case rightMost
        case up
        case topMost
        case down
        case bottomMost
    }

    let title: String
    let domain: String?
    var image: Image?
    var size: CGFloat = 32
    let tag: Int
    let action: () -> Void

    @EnvironmentObject var model: HomePage.Models.FavoritesModel
    @State var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .center) {

                    RoundedRectangle(cornerRadius: 12)
                        .foregroundColor(isHovering ? Color("HomeFavoritesHoverColor") : Color("HomeFavoritesBackgroundColor"))

                    FaviconView(domain: domain, image: image, size: size)
                        .frame(width: size, height: size)
                        .padding(9)
                }
                .frame(width: 64, height: 64)
                .clipped()
                .focusable(tag: tag, cornerRadius: 12, action: action, keyDown: { event in
                    let hasModifier = NSApp.isCommandPressed || NSApp.isOptionPressed
                    switch Int(event.keyCode) {
                    case kVK_LeftArrow:
                        selectView(withTag: tagForView(at: hasModifier ? .leftMost : .left, against: tag))
                    case kVK_RightArrow:
                        selectView(withTag: tagForView(at: hasModifier ? .rightMost : .right, against: tag))
                    case kVK_UpArrow:
                        selectView(withTag: tagForView(at: hasModifier ? .topMost : .up, against: tag))
                    case kVK_DownArrow:
                        selectView(withTag: tagForView(at: hasModifier ? .bottomMost : .down, against: tag))
                    default:
                        return event
                    }
                    return nil
                })

                Text(title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .font(.system(size: 11))
                    .frame(height: 32, alignment: .top)

            }
            .frame(width: 64)
            .frame(maxWidth: 64)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibility(addTraits: .isButton)
        .accessibility(label: .init(title))
        .accessibilityAction { action() }
        .onHover(update: $isHovering)
        .cursor(.pointingHand)

    }

    // swiftlint:disable:next cyclomatic_complexity
    private func tagForView(at direction: KeyViewDirection, against tag: Int) -> Int {
        var index: Int { tag % HomePage.favoritesPerRow }
        var row: Int { (tag - FavoriteTemplate.tagBase) / HomePage.favoritesPerRow }
        var count: Int { model.favorites.count + 1 /* new fav */ }

        switch direction {
        case .left:
            if tag > FavoriteTemplate.tagBase {
                return tag - 1
            } else {
                return count - 1 + FavoriteTemplate.tagBase
            }

        case .leftMost:
            return max(tag - index, FavoriteTemplate.tagBase)

        case .right:
            if (tag - FavoriteTemplate.tagBase) + 1 < count {
                return tag + 1
            } else {
                return FavoriteTemplate.tagBase
            }

        case .rightMost:
            return min(tag + (HomePage.favoritesPerRow - index - 1), FavoriteTemplate.tagBase + count - 1)

        case .up:
            if row > 0 {
                return tag - HomePage.favoritesPerRow
            } else {
                return tagForView(at: .bottomMost, against: tag)
            }

        case .topMost:
            return FavoriteTemplate.tagBase + index

        case .down:
            if (tag - FavoriteTemplate.tagBase) + HomePage.favoritesPerRow < count {
                return tag + HomePage.favoritesPerRow
            } else {
                return tagForView(at: .topMost, against: tag)
            }

        case .bottomMost:
            if index <= (count - 1) % HomePage.favoritesPerRow {
                return FavoriteTemplate.tagBase + count - (count % HomePage.favoritesPerRow) + index
            } else {
                return FavoriteTemplate.tagBase + count - (count % HomePage.favoritesPerRow) - HomePage.favoritesPerRow + index
            }
        }
    }

    private func selectView(withTag tag: Int) {
        guard let window = NSApp.keyWindow,
              let firstResponder = window.firstResponder as? NSView,
              let scrollView = firstResponder.enclosingScrollView,
              let view = scrollView.contentView.viewWithTag(tag)
        else {
            return
        }

        view.makeMeFirstResponder()
    }

}

struct Favorite: View {

    @EnvironmentObject var model: HomePage.Models.FavoritesModel

    let bookmark: Bookmark
    let tag: Int
    let action: () -> Void

    var body: some View {

        let menuProvider = MenuProvider([
            .item(title: UserText.openInNewTab, action: { model.openInNewTab(bookmark) }),
            .item(title: UserText.openInNewWindow, action: { model.openInNewWindow(bookmark) }),
            .divider,
            .item(title: UserText.edit, action: { model.edit(bookmark) }),
            .item(title: UserText.remove, action: { model.remove(bookmark) })
        ])

        FavoriteTemplate(title: bookmark.title, domain: bookmark.url.host, tag: tag, action: action)
            .contextMenu(menuItems: menuProvider.createContextMenu)

    }

}

}
