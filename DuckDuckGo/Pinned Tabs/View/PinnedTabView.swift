//
//  PinnedTabView.swift
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

struct PinnedTabView: View {
    enum Const {
        static let dimension: CGFloat = 32
    }

    @ObservedObject var model: Tab
    @EnvironmentObject var collectionModel: PinnedTabsViewModel
    @State var isHovered: Bool = false

    @Environment(\.controlActiveState) private var controlActiveState

    // Hover highlight is disabled while another tab is dragged
    var showsHover: Bool

    var body: some View {
        Button {
            if !isSelected {
                collectionModel.selectedItem = model
            }
        } label: {
            PinnedTabInnerView(
                foregroundColor: foregroundColor,
                drawSeparator: !collectionModel.itemsWithoutSeparator.contains(model)
            )
            .environmentObject(model)
        }
        .buttonStyle(TouchDownButtonStyle())
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .contextMenu { contextMenu }
        .onHover { isHovered in
            guard controlActiveState == .key else {
                return
            }
            self.isHovered = isHovered
            collectionModel.hoveredItem = isHovered ? model : nil
        }
    }

    private var isSelected: Bool {
        collectionModel.selectedItem == model
    }

    private var foregroundColor: Color {
        if isSelected {
            return Color("InterfaceBackgroundColor")
        }
        return showsHover && isHovered ? Color("TabMouseOverColor") : Color.clear
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(UserText.duplicateTab, action: { collectionModel.duplicate(model) })
        Button(UserText.unpinTab, action: { collectionModel.unpin(model) })
        Divider()
        Button(UserText.bookmarkThisPage, action: { collectionModel.bookmark(model) })
        fireproofAction
        Divider()
        Button(UserText.closeTab, action: { collectionModel.close(model) })
    }

    @ViewBuilder
    private var fireproofAction: some View {
        if collectionModel.isFireproof(model) {
            Button(UserText.removeFireproofing, action: { collectionModel.removeFireproofing(model) })
        } else {
            Button(UserText.fireproofSite, action: { collectionModel.fireproof(model) })
        }
    }
}

struct PinnedTabInnerView: View {
    var foregroundColor: Color
    var drawSeparator: Bool = true

    @EnvironmentObject var model: Tab
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(foregroundColor)
            if drawSeparator {
                GeometryReader { proxy in
                    Rectangle()
                        .foregroundColor(Color("SeparatorColor"))
                        .frame(width: 1, height: 20)
                        .offset(x: proxy.size.width-1, y: 6)
                }
            }
            favicon
                .grayscale(controlActiveState == .key ? 0.0 : 1.0)
                .opacity(controlActiveState == .key ? 1.0 : 0.60)
                .frame(maxWidth: 16, maxHeight: 16)
                .aspectRatio(contentMode: .fit)
        }
        .frame(width: PinnedTabView.Const.dimension)
    }

    @ViewBuilder
    var favicon: some View {
        if let favicon = model.favicon {
            Image(nsImage: favicon)
                .resizable()
        } else if let domain = model.content.url?.host, let firstLetter = domain.dropWWW().capitalized.first.flatMap(String.init) {
            ZStack {
                Rectangle()
                    .foregroundColor(.forDomain(domain.dropWWW()))
                Text(firstLetter)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .cornerRadius(4.0)
        } else {
            Image(nsImage: #imageLiteral(resourceName: "Web"))
                .resizable()
        }
    }
}
