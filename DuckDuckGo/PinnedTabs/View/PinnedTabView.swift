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
import SwiftUIExtensions

struct PinnedTabView: View {
    enum Const {
        static let dimension: CGFloat = 34
        static let cornerRadius: CGFloat = 10
    }

    @ObservedObject var model: Tab
    @EnvironmentObject var collectionModel: PinnedTabsViewModel

    @Environment(\.controlActiveState) private var controlActiveState

    // Hover highlight is disabled while another tab is dragged
    var showsHover: Bool

    var body: some View {
        let stack = ZStack {
            Button { [weak collectionModel, weak model] in
                if !isSelected {
                    collectionModel?.selectedItem = model
                }
            } label: {
                PinnedTabInnerView(
                    foregroundColor: foregroundColor,
                    drawSeparator: !collectionModel.itemsWithoutSeparator.contains(model)
                )
                .environmentObject(model)
            }
            .buttonStyle(TouchDownButtonStyle())
            .cornerRadius(Const.cornerRadius, corners: [.topLeft, .topRight])
            .contextMenu { contextMenu }

            BorderView(isSelected: isSelected,
                       cornerRadius: Const.cornerRadius,
                       size: TabShadowConfig.dividerSize)
        }

        if controlActiveState == .key {
            stack
                .onHover { [weak collectionModel, weak model] isHovered in
                    collectionModel?.hoveredItem = isHovered ? model : nil
                }
                .onMouseMoving { [weak collectionModel] in
                    collectionModel?.mouseMoving = ()
                }
        } else {
            stack
        }

    }

    private var isSelected: Bool {
        collectionModel.selectedItem == model
    }

    private var foregroundColor: Color {
        if isSelected {
            return .navigationBarBackground
        }
        let isHovered = collectionModel.hoveredItem == model
        return showsHover && isHovered ? .tabMouseOver : Color.clear
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(UserText.duplicateTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.duplicate(model)
        }

        Button(UserText.unpinTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.unpin(model)
        }
        Divider()
        bookmarkAction
        fireproofAction
        Divider()
        switch collectionModel.audioStateView {
        case .muted, .unmuted:
            let audioStateText = collectionModel.audioStateView == .muted ? UserText.unmuteTab : UserText.muteTab
            Button(audioStateText) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.muteOrUmute(model)
            }
            Divider()
        case .notSupported:
            EmptyView()
        }
        Button(UserText.closeTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.close(model)
        }
    }

    @ViewBuilder
    private var fireproofAction: some View {
        if collectionModel.isFireproof(model) {
            Button(UserText.removeFireproofing) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.removeFireproofing(model)
            }
        } else {
            Button(UserText.fireproofSite) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.fireproof(model)
            }
        }
    }

    @ViewBuilder
    private var bookmarkAction: some View {
        if collectionModel.isPinnedTabBookmarked(model) {
            Button(UserText.deleteBookmark) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.removeBookmark(model)
            }
        } else {
            Button(UserText.bookmarkThisPage) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.bookmark(model)
            }
        }
    }
}

private struct BorderView: View {
    let isSelected: Bool
    let cornerRadius: CGFloat
    let size: CGFloat

    private var borderColor: Color {
        isSelected ? .tabShadowLine : .clear
    }

    private var bottomLineColor: Color {
        isSelected ? .navigationBarBackground : .tabShadowLine
    }

    private var cornerPixelsColor: Color {
        isSelected ? .clear : bottomLineColor
    }

    var body: some View {
        ZStack {
            CustomRoundedCornersShape(inset: 0, tl: cornerRadius, tr: cornerRadius, bl: 0, br: 0)
                .strokeBorder(borderColor, lineWidth: size)

            VStack {
                Spacer()
                HStack {
                    Spacer().frame(width: 1, height: size, alignment: .leading)
                        .background(cornerPixelsColor)

                    Rectangle()
                        .fill(bottomLineColor)
                        .frame(height: size, alignment: .leading)

                    Spacer().frame(width: 1, height: size, alignment: .trailing)
                        .background(cornerPixelsColor)
                }
            }
        }
    }
}

struct PinnedTabInnerView: View {
    var foregroundColor: Color
    var drawSeparator: Bool = true

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: Tab
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(foregroundColor)
            if drawSeparator {
                GeometryReader { proxy in
                    Rectangle()
                        .foregroundColor(.separator)
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
    var mutedTabIndicator: some View {
        switch model.audioState {
        case .muted:
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                    .background(Circle().foregroundColor(.pinnedTabMuteStateCircle))
                    .frame(width: 16, height: 16)
                Image(.audioMute)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 12, height: 12)
            }.offset(x: 8, y: -8)
        case .unmuted, .none: EmptyView()
        }
    }

    @ViewBuilder
    var favicon: some View {
        if let favicon = model.favicon {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: favicon)
                    .resizable()
                mutedTabIndicator
            }
        } else if let domain = model.content.userEditableUrl?.host,
                  let eTLDplus1 = ContentBlocking.shared.tld.eTLDplus1(domain),
                  let firstLetter = eTLDplus1.capitalized.first.flatMap(String.init) {
            ZStack {
                Rectangle()
                    .foregroundColor(.forString(eTLDplus1))
                Text(firstLetter)
                    .font(.caption)
                    .foregroundColor(.white)
                mutedTabIndicator
            }
            .cornerRadius(4.0)
        } else {
            ZStack {
                Image(nsImage: .web)
                    .resizable()
                mutedTabIndicator
            }
        }
    }
}
